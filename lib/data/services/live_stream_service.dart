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
  String? _connectedLabel;

  // Prevent duplicate messages (bounded memory).
  final Map<String, DateTime> _seen = <String, DateTime>{};
  static const int _seenMax = 600;
  static const Duration _seenTtl = Duration(minutes: 10);
  static const Set<String> _typedActivitySocketEvents = <String>{
    'activity:join',
    'activity:follow',
    'activity:superchat',
    'activity:subscription',
    'activity:gifted_sub',
    'activity:resub',
    'activity:raid',
    'activity:bits',
    'activity:like',
    'activity:gift',
    'activity:share',
  };

  // ---- Callbacks (wired by controller) ----
  void Function()? onSocketConnected;
  void Function(String reason)? onSocketDisconnected;
  void Function(JsonMap payload)? onConnectedEvent;
  void Function(JsonMap payload)? onSettingsUpdate;
  void Function(List<JsonMap> events)? onActivitySync;
  void Function(JsonMap event)? onActivityEvent;
  void Function(JsonMap payload)? onStreamStatus;
  void Function(JsonMap payload)? onStreamLive;
  void Function(JsonMap payload)? onStreamInfoUpdate;
  void Function(String platform, int viewerCount)? onViewerCountUpdate;
  void Function(String platform, bool live)? onLiveUpdate;
  void Function(String platform, String? playerUrl)? onPlayerUrlUpdate;
  void Function(ChatMessage msg)? onChatMessage;
  void Function(JsonMap payload)? onLedNotification;
  void Function(JsonMap payload)? onStreamSettingsApplied;
  void Function(JsonMap payload)? onSocketError;

  bool get isSocketConnected => _socket?.connected == true;

  Future<StreamingOverview?> fetchOverview({
    required String platform,
    required String accessToken,
  }) {
    return _streaming.fetchOverview(platform: platform, accessToken: accessToken);
  }

  Future<List<ChatMessage>> loadHistory({
    required String platform,
    required String accessToken,
    int limit = 100,
    int offset = 0,
  }) {
    return _chat.loadHistory(
      platform: platform,
      accessToken: accessToken,
      limit: limit,
      offset: offset,
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

    if (_socket?.connected == true &&
        _connectedBaseUrl == normalizedBase &&
        _connectedPath == normalizedPath &&
        _connectedAccessToken == normalizedToken &&
        _connectedLabel == normalizedLabel) {
      return;
    }

    _manuallyDisconnected = false;
    _label = normalizedLabel;
    _connectSeq++;

    await disconnect();

    final socket = io.io(
      normalizedBase,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setPath(normalizedPath)
          // Backend supports handshake auth token.
          .setAuth({'token': normalizedToken})
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
      _connectedLabel = normalizedLabel;
      onSocketConnected?.call();
      _emitStart();
      _startHeartbeat();
    });

    socket.on('disconnect', (reason) {
      onSocketDisconnected?.call(reason?.toString() ?? '');
      _stopHeartbeat();
      if (!_manuallyDisconnected) _scheduleReconnectGuard();
    });

    socket.on('connect_error', (e) {
      final m = _asMap(e) ?? <String, dynamic>{'message': e.toString()};
      onSocketError?.call(m);
      if (!_manuallyDisconnected) _scheduleReconnectGuard();
    });

    // Server -> client events per API_SOCKET_DETAILS.md
    socket.on('connected', (d) {
      final m = _asMap(d);
      if (m != null) onConnectedEvent?.call(m);
    });

    socket.on('settings:update', (d) {
      final m = _asMap(d);
      if (m != null) onSettingsUpdate?.call(m);
    });

    socket.on('activity:sync', (d) {
      _logSocketEventPayload('activity:sync', d);
      final m = _asMap(d);
      if (m == null) return;
      final events = m['events'];
      if (events is! List) return;
      final list = <JsonMap>[];
      for (final e in events) {
        final em = _asMap(e);
        if (em != null) list.add(em);
      }
      onActivitySync?.call(list);
    });

    socket.on('activity:event', (d) {
      _handleActivitySocketEvent('activity:event', d);
    });

    for (final eventName in _typedActivitySocketEvents) {
      socket.on(eventName, (d) {
        _handleActivitySocketEvent(eventName, d);
      });
    }

    // Some backends emit typed activity channels (activity:join, activity:follow, ...).
    // Handle all activity:* names using the same payload shape.
    socket.onAny((eventName, data) {
      final name = eventName.toLowerCase().trim();
      if (!name.startsWith('activity:')) return;
      if (name == 'activity:sync' || name == 'activity:event') return;
      if (_typedActivitySocketEvents.contains(name)) return;
      _handleActivitySocketEvent(name, data);
    });

    void applyStreamPayload(JsonMap m, void Function(JsonMap payload)? cb) {
      cb?.call(m);
      final platform = (m['platform'] ?? '').toString().toLowerCase();
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
      final m = _asMap(d);
      if (m != null) applyStreamPayload(m, onStreamStatus);
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
      final platform = (m?['platform'] ?? '').toString().toLowerCase();
      final vc = _parseViewerCount(payload);
      if (platform.isNotEmpty && vc != null) {
        onViewerCountUpdate?.call(platform, vc);
      }
      _emitStart(); // keep session warm
    });

    socket.on('chat:message', (payload) {
      _logSocketEventPayload('chat:message', payload);
      final msg = _parseChatMessage(payload);
      if (msg == null) return;
      if (_dedupe(msg)) return;
      onChatMessage?.call(msg);
    });

    socket.on('led:notification', (d) {
      _logSocketEventPayload('led:notification', d);
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
    _connectedBaseUrl = null;
    _connectedPath = null;
    _connectedAccessToken = null;
    _connectedLabel = null;
  }

  // ---- Socket emits / keep-alive ----
  void _emitStart() {
    final now = DateTime.now();
    if (now.difference(_lastStartEmit) < const Duration(seconds: 2)) return;
    _lastStartEmit = now;
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
    var ticks = 0;
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_manuallyDisconnected) return;
      if (_socket?.connected != true) return;
      _emitStart();
      ticks++;
      if (ticks >= 12) {
        _heartbeatTimer?.cancel();
        _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (_) {
          if (_manuallyDisconnected) return;
          if (_socket?.connected != true) return;
          _emitStart();
        });
      }
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

      final platform =
          (map['platform'] ?? map['source'] ?? 'twitch').toString().trim().toLowerCase();
      final metadata = map['metadata'];
      final metaUser = metadata is Map
          ? (metadata['user'] ??
                  metadata['username'] ??
                  metadata['sender_username'] ??
                  metadata['senderUsername'] ??
                  metadata['name'] ??
                  metadata['displayName'])
              ?.toString()
          : null;

      var user = (map['sender_username'] ??
              map['senderUsername'] ??
              map['username'] ??
              map['user'] ??
              map['name'] ??
              map['displayName'] ??
              metaUser ??
              'Unknown')
          .toString()
          .trim();
      if (user.isEmpty) user = (metaUser ?? 'Unknown').toString().trim();

      final message = (map['message'] ?? map['text'] ?? '').toString();
      if (message.trim().isEmpty) return null;

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

  void _handleActivitySocketEvent(String socketEventName, dynamic payload) {
    _logSocketEventPayload(socketEventName, payload);
    if (kDebugMode) {
      debugPrint('[ACTIVITY_EVENT][$socketEventName][SOCKET_RAW] $payload');
    }

    final m = _asMap(payload);
    if (m == null) return;

    // Keep one normalized shape even when backend event channel is activity:<type>.
    final existingType = m['type']?.toString().trim();
    if (existingType == null || existingType.isEmpty) {
      final inferredType = _typeFromActivityEventName(socketEventName);
      if (inferredType != null) m['type'] = inferredType;
    }
    m['socketEvent'] = socketEventName;

    final normalizedType = (m['type'] ?? '').toString().toLowerCase().trim();
    if (normalizedType == 'follow' && kDebugMode) {
      final platform = (m['platform'] ?? '').toString();
      final metadata = m['metadata'];
      String follower = '';
      if (metadata is Map) {
        follower = (metadata['user_name'] ??
                metadata['username'] ??
                metadata['user_login'] ??
                metadata['displayName'] ??
                '')
            .toString()
            .trim();
      }
      debugPrint(
        '[FOLLOW_EVENT][RECEIVED] socket=$socketEventName platform=$platform follower=$follower payload=${jsonEncode(m)}',
      );
    }

    if (kDebugMode) {
      debugPrint('[ACTIVITY_EVENT][$socketEventName][SOCKET_PARSED] ${jsonEncode(m)}');
    }
    onActivityEvent?.call(m);
  }

  String? _typeFromActivityEventName(String socketEventName) {
    final name = socketEventName.toLowerCase().trim();
    if (!name.startsWith('activity:')) return null;
    final type = name.substring('activity:'.length).trim();
    if (type.isEmpty || type == 'event' || type == 'sync') return null;
    return type;
  }

  void _logSocketEventPayload(String eventName, dynamic payload) {
    if (!kDebugMode) return;
    String text;
    try {
      if (payload is String) {
        text = payload;
      } else {
        text = jsonEncode(payload);
      }
    } catch (_) {
      text = payload.toString();
    }
    debugPrint('[SOCKET] $_label#$_connectSeq $eventName');
    const chunk = 700;
    for (int i = 0; i < text.length; i += chunk) {
      final end = (i + chunk) < text.length ? (i + chunk) : text.length;
      debugPrint(text.substring(i, end));
    }
  }
}

