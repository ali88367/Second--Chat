import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../api/app_api.dart';
import '../../core/utils/platform_token_provider.dart';
import '../models/chat_message.dart';
import '../models/streaming_overview.dart';
import 'chat_service.dart';
import 'streaming_service.dart';

typedef JsonMap = Map<String, dynamic>;

const int _kInboundLogMaxChars = 12000;

dynamic _jsonSafeForInboundLog(dynamic v) {
  if (v == null || v is num || v is String || v is bool) return v;
  if (v is DateTime) return v.toIso8601String();
  if (v is Map) {
    final out = <String, dynamic>{};
    for (final e in v.entries) {
      out[e.key.toString()] = _jsonSafeForInboundLog(e.value);
    }
    return out;
  }
  if (v is Iterable) {
    return v.map(_jsonSafeForInboundLog).toList();
  }
  return v.toString();
}

String _payloadToInboundLogString(dynamic payload) {
  try {
    final s = jsonEncode(_jsonSafeForInboundLog(payload));
    if (s.length > _kInboundLogMaxChars) {
      return '${s.substring(0, _kInboundLogMaxChars)}…';
    }
    return s;
  } catch (_) {
    final s = payload.toString();
    if (s.length > _kInboundLogMaxChars) {
      return '${s.substring(0, _kInboundLogMaxChars)}…';
    }
    return s;
  }
}

/// Socket.IO often passes a single-arg payload as a one-element [List].
dynamic _unwrapSocketIoData(dynamic data) {
  if (data is List && data.length == 1) return data.first;
  return data;
}

bool _shouldRecordInboundSocketEvent(String eventName) {
  final n = eventName.toLowerCase().trim();
  if (n.startsWith('chat:')) return true;
  if (n == 'socket:connect' ||
      n == 'socket:disconnect' ||
      n == 'socket:connect_error' ||
      n == 'connected') {
    return true;
  }
  if (n == 'socket:unhandled_event') return true;
  return LiveStreamService.inboundLogNamedSocketEvents.contains(n);
}

/// Drop heavy `context` from [API_SOCKET_DETAILS.md] `chat:message` for log readability.
dynamic _chatMessagePayloadForLog(dynamic payload) {
  if (payload is! Map) return payload;
  try {
    final m = Map<String, dynamic>.from(payload.cast<String, dynamic>());
    m.remove('context');
    return m;
  } catch (_) {
    return payload;
  }
}

/// Live stream orchestration service:
/// - Fetches REST overview/history/send
/// - Manages Socket.IO connection + events
/// - Handles token refresh + persistence via [PlatformTokenProvider]
///
/// Controller should only keep Rx state and call into this service.
class LiveStreamService {
  LiveStreamService({
    AppApi? api,
    PlatformTokenProvider? tokenProvider,
    StreamingService? streaming,
    ChatService? chat,
  }) : _api = api ?? AppApi.create(),
       _tokenProvider = tokenProvider ?? PlatformTokenProvider(),
       _streaming = streaming ?? StreamingService((api ?? AppApi.create()).client.dio),
       _chat = chat ?? ChatService((api ?? AppApi.create()).client.dio);

  final AppApi _api;
  final PlatformTokenProvider _tokenProvider;
  final StreamingService _streaming;
  final ChatService _chat;

  io.Socket? _socket;
  String _label = 'live';
  int _connectSeq = 0;
  bool _manuallyDisconnected = false;

  Timer? _reconnectGuard;
  Timer? _heartbeatTimer;
  DateTime _lastStartEmit = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastStopEmit = DateTime.fromMillisecondsSinceEpoch(0);
  String? _connectedBaseUrl;
  String? _connectedPath;
  String? _connectedAccessToken;
  DateTime? _sessionConnectedAt;
  int _sessionInboundCount = 0;
  int _sessionChatMessageCount = 0;
  int _sessionStreamStatusCount = 0;
  int _sessionStreakStatusCount = 0;
  bool _sessionSummaryLogged = false;

  // Prevent duplicate messages (bounded memory).
  final Map<String, DateTime> _seen = <String, DateTime>{};
  static const int _seenMax = 600;
  static const Duration _seenTtl = Duration(minutes: 10);

  // ---- Callbacks (wired by controller) ----
  void Function()? onSocketConnected;
  void Function(String reason)? onSocketDisconnected;
  void Function(JsonMap payload)? onConnectedEvent;
  void Function(JsonMap payload)? onSettingsUpdate;
  void Function(JsonMap event)? onActivityEvent;
  void Function(JsonMap payload)? onStreamStatus;
  void Function(JsonMap payload)? onStreamLive;
  void Function(JsonMap payload)? onStreamInfoUpdate;
  void Function(JsonMap payload)? onStreakStatus;
  void Function(String platform, int viewerCount)? onViewerCountUpdate;
  void Function(String platform, bool live)? onLiveUpdate;
  void Function(String platform, String? playerUrl)? onPlayerUrlUpdate;
  void Function(ChatMessage msg)? onChatMessage;
  void Function(JsonMap payload)? onLedNotification;
  void Function(JsonMap payload)? onStreamSettingsApplied;
  void Function(JsonMap payload)? onSocketError;

  /// Inbound events for the socket log UI ([SocketLogScreen]): activity + live chat.
  void Function(String eventName, String payloadText)? onSocketInbound;

  bool get isSocketConnected => _socket?.connected == true;

  /// Connection parameters for the Socket.IO session that receives **`chat:message`**
  /// (and related §5 events), aligned with `API_SOCKET_DETAILS.md` §5 *Connection*.
  ///
  /// Does not include raw tokens — only a fingerprint of the handshake token.
  Map<String, dynamic> get chatMessageSocketConnectionDetails {
    final s = _socket;
    String? ioId;
    try {
      ioId = (s as dynamic).id?.toString();
    } catch (_) {
      ioId = null;
    }
    const transports = 'websocket, polling';
    return <String, dynamic>{
      'api_doc_reference': 'API_SOCKET_DETAILS.md §5 WebSocket (Socket.IO)',
      'inbound_chat_event': 'chat:message (§5.2)',
      'url_source': 'GET /streaming/overview → chatSocketUrl',
      'path_source': 'GET /streaming/overview → chatSocketPath',
      'base_url': _connectedBaseUrl?.trim().isNotEmpty == true
          ? _connectedBaseUrl!.trim()
          : '(awaiting connect / overview)',
      'socket_io_path': _connectedPath?.trim().isNotEmpty == true
          ? _connectedPath!.trim()
          : '(awaiting overview)',
      'transports': transports,
      'implements_transports_per_doc': true,
      'handshake_auth': 'auth: { "token": "<accessToken>" }',
      'handshake_header': 'Authorization: Bearer <accessToken>',
      'implements_auth_per_doc': true,
      'access_token_fingerprint': _tokenFingerprint(_connectedAccessToken),
      'transport_connected': s?.connected == true,
      'socket_io_session_id': ioId ?? '(after connect)',
      'client_emits_after_connect': 'chat:start (§5.1), periodic keep-alive',
      'listens_for_chat_message': true,
    };
  }

  static String _tokenFingerprint(String? token) {
    final t = token?.trim() ?? '';
    if (t.isEmpty) return '(none)';
    if (t.length <= 12) return 'len=${t.length}';
    return '${t.substring(0, 6)}…${t.substring(t.length - 4)} (len=${t.length})';
  }

  static bool _shouldLogUnhandledSocketEvent(String name) {
    final n = name.toLowerCase().trim();
    if (n.isEmpty) return false;
    if (n == 'ping' || n == 'pong') return false;
    if (n.contains('reconnect')) return false;
    if (n.startsWith('chat:')) return false;
    if (n.startsWith('activity:')) return false;
    if (n.startsWith('stream:')) return false;
    if (n.startsWith('streak:')) return false;
    if (n.startsWith('viewer_count')) return false;
    if (n == 'connected' ||
        n == 'settings:update' ||
        n == 'led:notification' ||
        n == 'error') {
      return false;
    }
    return true;
  }

  /// Logged by name (plus every inbound `chat:*`, [connected], socket session lines).
  static const Set<String> inboundLogNamedSocketEvents = <String>{
    'activity:event',
    'stream:info:update',
  };

  void _recordInboundSocket(String eventName, dynamic payload) {
    _sessionInboundCount++;
    final normalized = eventName.toLowerCase().trim();
    if (normalized == 'chat:message') _sessionChatMessageCount++;
    if (normalized == 'stream:status') _sessionStreamStatusCount++;
    if (normalized == 'streak:status') _sessionStreakStatusCount++;

    final cb = onSocketInbound;
    final shouldForward = _shouldRecordInboundSocketEvent(eventName);
    final payloadText = _payloadToInboundLogString(payload);

    if (kDebugMode) {
      debugPrint('[SOCKET_TRACE] $_label#$_connectSeq | $eventName | $payloadText');
    }

    if (cb == null) return;
    if (!shouldForward) return;
    cb(eventName, payloadText);
  }

  /// Inbound **`activity:event`** (all platforms): verify log, socket trace, then parse.
  void _onInboundActivityChannel(String socketEventName, dynamic d) {
    if (kDebugMode) {
      final rawWire = _payloadToInboundLogString(_unwrapSocketIoData(d));
      debugPrint('[ACTIVITY_VERIFY] $socketEventName RAW wire:\n$rawWire');
    }
    _recordInboundSocket(socketEventName, d);
    _handleActivitySocketEvent(socketEventName, d);
  }

  void _resetSessionTraceCounters() {
    _sessionConnectedAt = null;
    _sessionInboundCount = 0;
    _sessionChatMessageCount = 0;
    _sessionStreamStatusCount = 0;
    _sessionStreakStatusCount = 0;
    _sessionSummaryLogged = false;
  }

  void _logSessionSummary({
    required String reason,
    required String source,
  }) {
    if (_sessionSummaryLogged) return;
    _sessionSummaryLogged = true;

    final connectedAt = _sessionConnectedAt;
    final duration = connectedAt == null
        ? null
        : DateTime.now().difference(connectedAt).inSeconds;

    if (kDebugMode) {
      debugPrint(
        '[SOCKET_TRACE] $_label#$_connectSeq | summary | source=$source reason=$reason '
        'connected_for_s=${duration ?? 'n/a'} inbound=$_sessionInboundCount '
        'chat:message=$_sessionChatMessageCount stream:status=$_sessionStreamStatusCount '
        'streak:status=$_sessionStreakStatusCount',
      );
    }
  }

  String _normalizePlatform(String? raw) {
    final v = (raw ?? '').toLowerCase().trim();
    if (v.isEmpty) return '';
    if (v.contains('twitch')) return 'twitch';
    if (v.contains('kick')) return 'kick';
    if (v.contains('youtube') || v == 'yt' || v.contains('google')) {
      return 'youtube';
    }
    if (v.contains('tiktok')) return 'tiktok';
    return v;
  }

  Future<StreamingOverview?> fetchOverview({
    required String platform,
    required String accessToken,
  }) {
    return _streaming.fetchOverview(platform: platform, accessToken: accessToken);
  }

  Future<ChatHistoryLoadResult> loadHistory({
    required String platform,
    required String accessToken,
    int limit = 100,
    int offset = 0,
    void Function(String eventName, String payloadText)? onLogLine,
  }) {
    return _chat.loadHistory(
      platform: platform,
      accessToken: accessToken,
      limit: limit,
      offset: offset,
      onLogLine: onLogLine,
    );
  }

  Future<void> sendMessage({
    required String platform,
    required String accessToken,
    required String message,
  }) {
    return _chat.sendMessage(
      platform: platform,
      accessToken: accessToken,
      message: message,
    );
  }

  /// Returns a platform access token; if it’s close to expiring (JWT exp),
  /// refreshes using the stored platform refresh token and persists tokens.
  Future<String?> ensureFreshPlatformAccessToken({
    required String platform,
    Duration refreshSkew = const Duration(seconds: 60),
  }) async {
    final key = platform.toLowerCase().trim();
    if (key.isEmpty) return null;

    final access = await _tokenProvider.getAccessToken(key);
    final refresh = await _tokenProvider.getRefreshToken(key);
    if (access == null || access.trim().isEmpty) return null;
    if (refresh == null || refresh.trim().isEmpty) return access.trim();

    final exp = _jwtExpSeconds(access);
    if (exp == null) return access.trim();

    final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final skewSec = refreshSkew.inSeconds;
    if (exp - nowSec > skewSec) return access.trim();

    final newTokens = await _api.auth.refresh(refresh.trim());
    await _tokenProvider.setPlatformTokens(
      platform: key,
      accessToken: newTokens.accessToken,
      refreshToken: newTokens.refreshToken,
    );
    return newTokens.accessToken.trim();
  }

  /// Opens the Socket.IO connection used for **`chat:message`** and all other §5 events.
  ///
  /// Matches `API_SOCKET_DETAILS.md` §5 *Connection*:
  /// - Engine transports: **`websocket`**, **`polling`** (`/socket.io` endpoint via [path]).
  /// - Auth: **`socket.handshake.auth.token`** and **`Authorization: Bearer <accessToken>`**.
  ///
  /// [baseUrl] / [path] come from overview **`chatSocketUrl`** / **`chatSocketPath`**.
  /// [accessToken] must be the **Second Chat backend** JWT (or platform token your API accepts),
  /// not a Google `ya29…` OAuth access token.
  Future<void> connect({
    required String baseUrl,
    required String path,
    required String accessToken,
    required String label,
  }) async {
    final normalizedBase = baseUrl.trim();
    final normalizedPath = path.trim();
    final normalizedToken = accessToken.trim();
    final normalizedLabel = label.trim().isEmpty ? 'live' : label.trim();

    // Same room for this user: reconnecting only to change [label] drops `chat:message` briefly.
    if (_socket?.connected == true &&
        _connectedBaseUrl == normalizedBase &&
        _connectedPath == normalizedPath &&
        _connectedAccessToken == normalizedToken) {
      _label = normalizedLabel;
      return;
    }

    _label = normalizedLabel;
    _connectSeq++;

    await disconnect();
    // [disconnect] marks manual=true; this new connect session must re-enable
    // heartbeat + reconnect guards for timeout/disconnect recovery.
    _manuallyDisconnected = false;
    _resetSessionTraceCounters();

    final socket = io.io(
      normalizedBase,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setPath(normalizedPath)
          .setAuth({'token': normalizedToken})
          // Some deployments read Bearer during handshake (see API_SOCKET_DETAILS.md).
          .setExtraHeaders(<String, String>{
            'Authorization': 'Bearer $normalizedToken',
          })
          .enableForceNew()
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(999999)
          .setReconnectionDelay(700)
          .setReconnectionDelayMax(4000)
          .build(),
    );

    _socket = socket;

    socket.on('connect', (_) {
      _connectedBaseUrl = normalizedBase;
      _connectedPath = normalizedPath;
      _connectedAccessToken = normalizedToken;
      _sessionConnectedAt = DateTime.now();
      _recordInboundSocket('socket:connect', {
        'url': normalizedBase,
        'path': normalizedPath,
        'transports': ['websocket', 'polling'],
        'auth':
            'handshake auth.token + Authorization: Bearer <accessToken> (§5 Connection)',
        'perApiDoc': 'GET /streaming/overview → chatSocketUrl + chatSocketPath',
        'afterConnect': 'emit chat:start (starts session; server sends settings:update)',
        'timestamp': DateTime.now().toIso8601String(),
      });
      onSocketConnected?.call();
      _emitStart();
      _startHeartbeat();
    });

    socket.on('disconnect', (reason) {
      _recordInboundSocket('socket:disconnect', {
        'reason': reason?.toString() ?? '',
      });
      _logSessionSummary(
        reason: reason?.toString() ?? 'unknown',
        source: 'socket.on(disconnect)',
      );
      // Programmatic [disconnect] sets [_manuallyDisconnected] before dispose; that path
      // invokes [onSocketDisconnected] once at the end of [disconnect] to avoid double
      // callbacks and to cover dispose() not emitting this event synchronously.
      if (!_manuallyDisconnected) {
        onSocketDisconnected?.call(reason?.toString() ?? '');
      }
      _stopHeartbeat();
      if (!_manuallyDisconnected) _scheduleReconnectGuard();
    });

    socket.on('connect_error', (e) {
      final m = _asMap(e) ?? <String, dynamic>{'message': e.toString()};
      _recordInboundSocket('socket:connect_error', m);
      onSocketError?.call(m);
      if (!_manuallyDisconnected) _scheduleReconnectGuard();
    });

    // Server -> client events per API_SOCKET_DETAILS.md
    socket.on('connected', (d) {
      final u = _unwrapSocketIoData(d);
      _recordInboundSocket('connected', u);
      final m = _asMap(u);
      if (m != null) onConnectedEvent?.call(m);
    });

    socket.on('settings:update', (d) {
      _recordInboundSocket('settings:update', d);
      final m = _asMap(d);
      if (m == null) {
        _recordInboundSocket('settings:update:parse_failed', <String, dynamic>{
          'hint': 'Server sent settings:update but payload could not be mapped',
          'raw': _payloadToInboundLogString(d),
        });
        return;
      }
      onSettingsUpdate?.call(m);
    });

    // `activity:sync` is ignored: it can arrive after `activity:event` and would wipe the
    // activity list if applied. Activity rail is driven by `activity:event` + REST history merge.

    // All platforms: **`activity:event`** only — body `type` carries the kind
    // (`join`, `follow`, `subscribe`, `unsubscribe`, …).
    socket.on(
      'activity:event',
      (d) => _onInboundActivityChannel('activity:event', d),
    );

    socket.onAny((eventName, data) {
      final ev = eventName.toString();
      final name = ev.toLowerCase().trim();
      // Log every server `chat:*` event (trim chat:message per API_SOCKET_DETAILS.md).
      if (name.startsWith('chat:')) {
        var logPayload = _unwrapSocketIoData(data);
        if (name == 'chat:message') {
          logPayload = _chatMessagePayloadForLog(logPayload);
        }
        _recordInboundSocket(ev, logPayload);
      } else if (_shouldLogUnhandledSocketEvent(name)) {
        // Helps find alternate event names if the backend does not use `chat:message` for third-party lines.
        _recordInboundSocket('socket:unhandled_event', <String, dynamic>{
          'event': ev,
          'payload_preview': _payloadToInboundLogString(_unwrapSocketIoData(data)),
        });
      }
    });

    void applyStreamPayload(JsonMap m, void Function(JsonMap payload)? cb) {
      cb?.call(m);
      final platform = _normalizePlatform((m['platform'] ?? '').toString());
      if (platform.isNotEmpty) {
        final liveRaw = m['live'];
        if (liveRaw is bool) onLiveUpdate?.call(platform, liveRaw);

        final vc = _parseViewerCount(m);
        if (vc != null) onViewerCountUpdate?.call(platform, vc);

        final playerAny = m['player'];
        if (playerAny is Map) {
          final player = playerAny.cast<String, dynamic>();
          final embedUrl = (player['embedUrl'] ?? player['embed_url'])?.toString();
          final watchUrl =
              (player['watchUrl'] ?? player['watch_url'] ?? player['url'])?.toString();
          final preferred = (embedUrl != null && embedUrl.trim().isNotEmpty)
              ? embedUrl.trim()
              : (watchUrl?.trim().isNotEmpty == true ? watchUrl!.trim() : null);
          onPlayerUrlUpdate?.call(platform, preferred);
        }
      }
    }

    socket.on('stream:status', (d) {
      _recordInboundSocket('stream:status', d);
      final m = _asMap(d);
      if (m == null) {
        _recordInboundSocket('stream:status:parse_failed', <String, dynamic>{
          'hint': 'Server sent stream:status but payload could not be mapped',
          'raw': _payloadToInboundLogString(d),
        });
        return;
      }
      applyStreamPayload(m, onStreamStatus);
    });

    socket.on('streak:status', (d) {
      _recordInboundSocket('streak:status', d);
      final m = _asMap(d);
      if (m == null) {
        _recordInboundSocket('streak:status:parse_failed', <String, dynamic>{
          'hint': 'Server sent streak:status but payload could not be mapped',
          'raw': _payloadToInboundLogString(d),
        });
        return;
      }
      onStreakStatus?.call(m);
    });

    socket.on('stream:live', (d) {
      final m = _asMap(d);
      if (m != null) applyStreamPayload(m, onStreamLive);
    });

    socket.on('stream:info:update', (d) {
      final m = _asMap(d);
      if (m != null) applyStreamPayload(m, onStreamInfoUpdate);
    });

    socket.on('viewer_count:update', (payload) {
      final m = _asMap(payload);
      final platform = _normalizePlatform((m?['platform'] ?? '').toString());
      final vc = _parseViewerCount(payload);
      if (platform.isNotEmpty && vc != null) {
        onViewerCountUpdate?.call(platform, vc);
      }
      // Heartbeat already emits `chat:start`; avoid extra emits every ~15s (reduces load + UI churn).
    });

    socket.on('chat:message', (payload) {
      final p = _unwrapSocketIoData(payload);
      final msg = _parseChatMessage(p);
      if (msg == null) {
        _recordInboundSocket('chat:message:parse_failed', <String, dynamic>{
          'hint':
              'Server sent chat:message but payload could not be mapped to ChatMessage (missing body or shape).',
          'raw_preview': _payloadToInboundLogString(
            p is Map ? _chatMessagePayloadForLog(p) : p,
          ),
        });
        return;
      }
      if (_dedupe(msg)) {
        if (kDebugMode) {
          _recordInboundSocket('chat:message:dedupe_skipped', <String, dynamic>{
            'dedupe_key': msg.dedupeKey,
            'userName': msg.userName,
            'message_preview': msg.message.length > 80
                ? '${msg.message.substring(0, 80)}…'
                : msg.message,
          });
        }
        return;
      }
      onChatMessage?.call(msg);
    });

    socket.on('led:notification', (d) {
      final m = _asMap(d);
      if (m != null) onLedNotification?.call(m);
    });

    socket.on('stream:settings:applied', (d) {
      final m = _asMap(d);
      if (m != null) onStreamSettingsApplied?.call(m);
    });

    socket.on('error', (d) {
      final m = _asMap(d) ?? <String, dynamic>{'message': d.toString()};
      onSocketError?.call(m);
    });

    socket.connect();
  }

  Future<void> disconnect() async {
    _reconnectGuard?.cancel();
    _reconnectGuard = null;
    _stopHeartbeat();
    _manuallyDisconnected = true;
    _recordInboundSocket('socket:manual_disconnect_called', {
      'connected': _socket?.connected == true,
      'timestamp': DateTime.now().toIso8601String(),
    });
    try {
      _emitStop();
    } catch (_) {}
    try {
      _socket?.dispose();
    } catch (_) {
      try {
        _socket?.disconnect();
      } catch (_) {}
    }
    _socket = null;
    _logSessionSummary(reason: 'manual_disconnect', source: 'disconnect()');
    _connectedBaseUrl = null;
    _connectedPath = null;
    _connectedAccessToken = null;
    try {
      onSocketDisconnected?.call('manual_disconnect');
    } catch (_) {}
  }

  // ---- Socket emits / keep-alive ----
  void _emitStart() {
    final now = DateTime.now();
    if (now.difference(_lastStartEmit) < const Duration(seconds: 2)) return;
    _lastStartEmit = now;
    _recordInboundSocket('emit:chat:start', {
      'timestamp': now.toIso8601String(),
      'connected': _socket?.connected,
    });
    _socket?.emit('chat:start');
  }

  void _emitStop() {
    final now = DateTime.now();
    if (now.difference(_lastStopEmit) < const Duration(milliseconds: 800)) return;
    _lastStopEmit = now;
    _socket?.emit('chat:stop');
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    // Align with server viewer polling (~15s) and avoid hammering `chat:start`.
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_manuallyDisconnected) return;
      if (_socket?.connected != true) return;
      _emitStart();
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _scheduleReconnectGuard() {
    _reconnectGuard?.cancel();
    _reconnectGuard = Timer(const Duration(seconds: 2), () {
      try {
        _socket?.connect();
      } catch (_) {}
    });
  }

  // ---- Parsing helpers ----
  int? _parseViewerCount(dynamic payload) {
    try {
      if (payload is int) return payload;
      if (payload is num) return payload.toInt();
      if (payload is String) return int.tryParse(payload.trim());
      if (payload is Map) {
        final m = payload.cast<String, dynamic>();
        final v = m['viewerCount'] ??
            m['viewer_count'] ??
            m['count'] ??
            m['viewers'] ??
            m['liveViewerCount'] ??
            m['live_viewer_count'];
        if (v is num) return v.toInt();
        if (v is String) return int.tryParse(v.trim());
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Merges optional nested `data` / `payload` maps so providers can wrap the row.
  Map<String, dynamic> _flattenChatMessageMap(Map<String, dynamic> top) {
    Map<String, dynamic>? layer(dynamic v) {
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return v.cast<String, dynamic>();
      return null;
    }

    final data = layer(top['data']);
    final inner = layer(top['payload']);
    var merged = top;
    if (data != null) merged = {...data, ...merged};
    if (inner != null) merged = {...inner, ...merged};
    return merged;
  }

  /// Treats null and blank strings as missing so `username: ""` still falls back to metadata.
  String? _nonEmptyString(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  String? _coalesceChatBody(Map<String, dynamic> map, dynamic metadata) {
    dynamic pick(dynamic a, dynamic b) {
      final s = a?.toString().trim() ?? '';
      if (s.isNotEmpty) return a;
      final t = b?.toString().trim() ?? '';
      return t.isNotEmpty ? b : null;
    }

    var v = pick(
      map['message'],
      map['text'],
    );
    v ??= pick(map['body'], null);
    if (v == null) {
      final content = map['content'];
      if (content is Map) {
        final cm = content.cast<String, dynamic>();
        v = pick(cm['text'], cm['message']);
        v ??= pick(cm['body'], null);
      } else {
        v = pick(map['content'], null);
      }
    }
    v ??= pick(map['msg'], null);
    if (metadata is Map) {
      final mm = metadata.cast<String, dynamic>();
      v ??= pick(mm['message'], mm['text']);
      v ??= pick(mm['body'], mm['content']);
    }
    if (v == null) {
      final sn = map['snippet'];
      if (sn is Map) {
        final sm = sn.cast<String, dynamic>();
        v = pick(sm['text'], sm['message']);
      }
    }
    final out = v?.toString() ?? '';
    return out.trim().isEmpty ? null : out;
  }

  /// Parses `chat:message` JSON per API (incl. Kick: `username`, `message`, `emotes`, `segments`,
  /// `streamId`, nested `metadata`).
  ChatMessage? _parseChatMessage(dynamic payload) {
    try {
      Map<String, dynamic>? map;
      if (payload is Map) {
        map = payload.cast<String, dynamic>();
      } else if (payload is String) {
        final decoded = jsonDecode(payload);
        if (decoded is Map) map = decoded.cast<String, dynamic>();
      }
      if (map == null) return null;
      map = _flattenChatMessageMap(map);

      final metadata = map['metadata'];
      final platform = _normalizePlatform(
        (map['platform'] ??
                map['source'] ??
                (metadata is Map ? metadata['platform'] : null) ??
                'twitch')
            .toString(),
      );
      // `chat:message` canonical sender: top-level `username` (Kick/Twitch/…). Other keys are legacy fallbacks.
      final metaUser = metadata is Map
          ? _nonEmptyString(metadata['login']) ??
              _nonEmptyString(metadata['user_login']) ??
              _nonEmptyString(metadata['userLogin']) ??
              _nonEmptyString(metadata['sender_username']) ??
              _nonEmptyString(metadata['senderUsername']) ??
              _nonEmptyString(metadata['username']) ??
              _nonEmptyString(metadata['user']) ??
              _nonEmptyString(metadata['name']) ??
              _nonEmptyString(metadata['displayName']) ??
              _nonEmptyString(metadata['display_name'])
          : null;

      var user = _nonEmptyString(map['username']) ??
          _nonEmptyString(map['sender_username']) ??
          _nonEmptyString(map['senderUsername']) ??
          _nonEmptyString(map['login']) ??
          _nonEmptyString(map['user_login']) ??
          _nonEmptyString(map['userLogin']) ??
          _nonEmptyString(map['user']) ??
          _nonEmptyString(map['name']) ??
          _nonEmptyString(map['displayName']) ??
          _nonEmptyString(map['display_name']) ??
          metaUser ??
          'Unknown';

      final message = _coalesceChatBody(map, metadata);
      if (message == null) return null;

      final id = (map['platform_message_id'] ??
              map['platformMessageId'] ??
              map['id'] ??
              map['_id'] ??
              map['messageId'])
          ?.toString();

      final tsRaw = (metadata is Map
              ? (metadata['timestamp'] ?? metadata['ts'] ?? metadata['time'])
              : null) ??
          map['timestamp'] ??
          map['created_at'] ??
          map['createdAt'] ??
          map['ts'] ??
          map['time'];
      final ts = _parseTimestamp(tsRaw) ?? DateTime.now().toUtc();

      return ChatMessage(
        platform: platform,
        userName: user,
        message: message,
        timestamp: ts,
        id: id,
        raw: map,
      );
    } catch (_) {
      return null;
    }
  }

  DateTime? _parseTimestamp(dynamic tsRaw) {
    if (tsRaw == null) return null;
    if (tsRaw is int) {
      if (tsRaw > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(tsRaw, isUtc: true);
      }
      return DateTime.fromMillisecondsSinceEpoch(tsRaw * 1000, isUtc: true);
    }
    if (tsRaw is String) return DateTime.tryParse(tsRaw);
    return null;
  }

  bool _dedupe(ChatMessage msg) {
    final now = DateTime.now().toUtc();
    final cutoff = now.subtract(_seenTtl);
    _seen.removeWhere((_, t) => t.isBefore(cutoff));

    final key = msg.dedupeKey;
    if (_seen.containsKey(key)) return true;
    _seen[key] = now;

    if (_seen.length > _seenMax) {
      final keys = _seen.keys.toList(growable: false);
      final removeCount = (_seen.length - _seenMax) + 50;
      for (var i = 0; i < removeCount && i < keys.length; i++) {
        _seen.remove(keys[i]);
      }
    }
    return false;
  }

  Map<String, dynamic>? _asMap(dynamic payload) {
    try {
      if (payload is Map<String, dynamic>) return payload;
      if (payload is Map) return payload.cast<String, dynamic>();
      if (payload is String) {
        final decoded = jsonDecode(payload);
        if (decoded is Map) return decoded.cast<String, dynamic>();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  int? _jwtExpSeconds(String? token) {
    final t = token?.trim();
    if (t == null || t.isEmpty) return null;
    final parts = t.split('.');
    if (parts.length < 2) return null;
    final payload = parts[1];
    try {
      final normalized = payload + '=' * ((4 - (payload.length % 4)) % 4);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final json = jsonDecode(decoded);
      if (json is Map) {
        final expRaw = json['exp'];
        if (expRaw is num) return expRaw.toInt();
      }
    } catch (_) {}
    return null;
  }

  void logDebug(String event, Object? payload) {
    if (!kDebugMode) return;
    debugPrint('[LiveStreamService] $_label#$_connectSeq $event ${payload ?? ''}');
  }

  /// Normalizes `type` for **`activity:event`** rows (body `type` / `eventType` / `kind`).
  void _coalesceActivityType(JsonMap m, String socketEventName) {
    var t = m['type']?.toString().trim();
    if (t == null || t.isEmpty) {
      final et = m['eventType']?.toString().trim();
      if (et != null && et.isNotEmpty) {
        m['type'] = et;
        t = et;
      }
    }
    if (t == null || t.isEmpty) {
      final k = m['kind']?.toString().trim();
      if (k != null && k.isNotEmpty) {
        m['type'] = k;
      }
    }
  }

  /// For **`activity:event`**, normalizes **`join` / `follow`** casing only; other `type` values
  /// (e.g. YouTube **`subscribe`**) are left unchanged.
  void _normalizeJoinFollowFromActivityEvent(JsonMap m) {
    final raw = m['type']?.toString().trim().toLowerCase();
    if (raw == 'join' || raw == 'follow') {
      m['type'] = raw;
      return;
    }
    if (kDebugMode && (raw == null || raw.isEmpty)) {
      debugPrint(
        '[ACTIVITY_SOCKET] activity:event missing `type` (e.g. join|follow|subscribe): $m',
      );
    }
  }

  void _handleActivitySocketEvent(String socketEventName, dynamic payload) {
    final m = _asMap(_unwrapSocketIoData(payload));
    if (m == null) {
      if (kDebugMode) {
        debugPrint('[ACTIVITY_SOCKET] $socketEventName (unparsed) $payload');
      }
      return;
    }

    _coalesceActivityType(m, socketEventName);
    if (socketEventName.toLowerCase().trim() == 'activity:event') {
      _normalizeJoinFollowFromActivityEvent(m);
    }
    m['socketEvent'] = socketEventName;

    if (kDebugMode) {
      try {
        debugPrint(
          '[ACTIVITY_VERIFY] $socketEventName NORMALIZED (after type merge):\n'
          '${jsonEncode(m)}',
        );
      } catch (_) {
        debugPrint('[ACTIVITY_VERIFY] $socketEventName NORMALIZED: $m');
      }
    }
    onActivityEvent?.call(m);
  }

}

