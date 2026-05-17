import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'auth_controller.dart';
import 'edge_glow_notification_controller.dart';
import '../controllers/Main Section Controllers/settings_controller.dart';
import '../controllers/Main Section Controllers/streak_controller.dart';
import '../core/utils/platform_token_provider.dart';
import '../data/models/chat_message.dart';
import '../data/models/streaming_overview.dart';
import '../data/services/live_stream_service.dart';
import '../data/services/socket_firebase_mirror_service.dart';
import '../api/auth/google_sign_in_service.dart';

class ChatController extends GetxController {
  ChatController({
    PlatformTokenProvider? tokenProvider,
    LiveStreamService? liveStreamService,
  }) : _tokenProvider = tokenProvider ?? PlatformTokenProvider(),
        _live =
            liveStreamService ??
                LiveStreamService(
                  tokenProvider: tokenProvider ?? PlatformTokenProvider(),
                );

  final PlatformTokenProvider _tokenProvider;
  final SettingsController _settings = Get.find<SettingsController>();
  final EdgeGlowNotificationController _edgeGlow =
  Get.find<EdgeGlowNotificationController>();
  final LiveStreamService _live;
  late final SocketFirebaseMirrorService _firebaseMirror;

  final RxString platform = 'twitch'.obs;

  final RxnString watchUrl = RxnString();
  final RxBool isLive = false.obs;
  final Rxn<StreamingOverview> overview = Rxn<StreamingOverview>();
  final RxMap<String, int> platformViewerCounts = <String, int>{}.obs;
  final RxMap<String, bool> platformLive = <String, bool>{}.obs;
  final RxMap<String, String?> platformEmbedUrls = <String, String?>{}.obs;

  /// Per-platform: embed [StreamWebView] finished first load (`onStreamReady`).
  /// Chat UI hides lines for live platforms until true.
  final RxMap<String, bool> platformStreamEmbedReady = <String, bool>{}.obs;

  /// Linked channel login from streaming overview `platforms[]` (optimistic send label).
  final RxMap<String, String> platformChatUsernames = <String, String>{}.obs;
  final RxMap<String, String?> streamTitleByPlatform = <String, String?>{}.obs;
  final RxMap<String, String?> streamCategoryByPlatform =
      <String, String?>{}.obs;
  final RxList<Map<String, dynamic>> activityEvents =
      <Map<String, dynamic>>[].obs;

  /// Per-platform chat lists. The UI reads [messages] which is the current
  /// selected platform list (swapped on platform changes).
  final RxMap<String, List<ChatMessage>> platformMessages =
      <String, List<ChatMessage>>{}.obs;

  Timer? _connectRetryTimer;
  bool _realtimeObserversWired = false;
  bool _socketConnecting = false;
  Future<void>? _bootstrapInFlight;
  DateTime _lastSocketConnectAttempt = DateTime.fromMillisecondsSinceEpoch(0);
  final Map<String, DateTime> _historyLastFetchAt = <String, DateTime>{};
  static const Duration _historyMinRefreshInterval = Duration(seconds: 25);
  /// Merges overlapping refreshes for the same platform (avoids duplicate HTTP).
  final Map<String, Future<void>> _overviewRefreshCoalesce =
  <String, Future<void>>{};

  /// One in-flight `GET /chat/history` per platform (callers await the same [Future]).
  final Map<String, Future<void>> _historyRefreshCoalesce =
  <String, Future<void>>{};

  /// Dedupe chat-derived rows merged into [activityEvents] (history refresh + socket).
  final Set<String> _activityChatSourceDedupeIds = <String>{};
  /// Dedupe realtime `activity:event` rows (and chat-derived activity merges).
  final Set<String> _activityRealtimeDedupeKeys = <String>{};
  final Map<String, DateTime> _edgeGlowEventSeenAt = <String, DateTime>{};
  final Set<String> _historyTriggeredForRunningStream = <String>{};
  final Map<String, int> _liveSessionSeqByPlatform = <String, int>{};
  final Map<String, Timer> _pendingOfflineTimers = <String, Timer>{};
  final Map<String, int> _pendingOfflineVotes = <String, int>{};
  final Map<String, DateTime> _lastConfirmedLiveAt = <String, DateTime>{};
  final Map<String, DateTime> _lastPlayerUrlUpdateAt = <String, DateTime>{};
  final RxMap<String, String> platformLastStopReason = <String, String>{}.obs;

  /// User disconnected this platform from the Connect sheet; keep UI/stream off
  /// until OAuth reconnect clears it, even if the socket still sends `live: true`.
  final Set<String> _oauthUserDisconnectedPlatforms = <String>{};

  static const int _offlineConfirmationVotes = 2;
  static const Duration _offlineConfirmationDelay = Duration(seconds: 6);
  static const Duration _minLiveHoldAfterTrue = Duration(seconds: 18);

  /// Own messages: show immediately, then replace with the socket echo (same text).
  final List<_PendingLocalChatEcho> _pendingLocalChatEchoes = [];

  final RxList<ChatMessage> messages = <ChatMessage>[].obs;
  final RxInt viewerCount = 0.obs;
  final RxBool isConnected = false.obs;

  final RxInt scrollTick = 0.obs; // UI can observe this to auto-scroll.

  /// Auth for Socket.IO + `/api/v1/chat/*`: session JWT, then stored Google access token, then platform OAuth ([_resolveChatAuthToken]).
  String? _socketAuthToken;
  String? _socketBaseUrl;
  String? _socketPath;

  /// Newest-first lines: `time | event | payload` — socket session (`socket:connect`, `connected`),
  /// `chat:*` / activity, and `api:chat/history` (REST `data` only on success/error body).
  final RxList<String> socketInboundLog = <String>[].obs;
  static const int _socketInboundLogMax = 600;

  void clearSocketInboundLog() => socketInboundLog.clear();

  /// §5 Socket.IO connection that carries **`chat:message`** (see `API_SOCKET_DETAILS.md`).
  Map<String, dynamic> get chatMessageSocketConnectionDetails =>
      _live.chatMessageSocketConnectionDetails;

  /// Inserts one `CHAT_MESSAGE_SOCKET` line into [socketInboundLog] (JSON snapshot).
  void appendChatMessageSocketConnectionToLog() {
    final report = <String, dynamic>{
      ..._live.chatMessageSocketConnectionDetails,
      'app_rx_is_connected': isConnected.value,
      'app_ui_selected_platform': platform.value,
      'overview_chat_socket_url': _socketBaseUrl ?? '',
      'overview_chat_socket_path': _socketPath ?? '',
      'chat_auth_token_fingerprint': _maskToken(_socketAuthToken),
    };
    final ts = DateTime.now().toIso8601String();
    final line = '$ts | CHAT_MESSAGE_SOCKET | ${jsonEncode(report)}';
    socketInboundLog.insert(0, line);
    while (socketInboundLog.length > _socketInboundLogMax) {
      socketInboundLog.removeLast();
    }
  }

  void _appendSocketInboundLog(String eventName, String payloadText) {
    final ts = DateTime.now().toIso8601String();
    final line = '$ts | $eventName | $payloadText';
    socketInboundLog.insert(0, line);
    while (socketInboundLog.length > _socketInboundLogMax) {
      socketInboundLog.removeLast();
    }
    _mirrorCurrentPlatformSnapshot(event: eventName);
  }

  /// Backend session JWT (same as [AuthInterceptor]) + platform tokens for overview/socket.
  /// Google Sign-In supplies an **id token** once to `/auth/google`; the server returns this JWT.
  Future<String?> _resolveStreamingRestToken(String platformKey) async {
    final p = platformKey.toLowerCase().trim();
    if (p.isEmpty) return null;

    // Prefer Google OAuth when accepted by endpoint.
    final googleToken =
    (await GoogleSignInService.instance.readStoredGoogleAccessToken())
        ?.trim();
    if (googleToken != null && googleToken.isNotEmpty) {
      _mirrorLatestApiAccessToken(
        token: googleToken,
        source: 'resolve_streaming_rest_token:google_access_token',
        platformKey: p,
      );
      return googleToken;
    }

    // Fallback to app session JWT.
    try {
      final session = await Get.find<AuthController>().api.tokenStore.read();
      final appJwt = session?.accessToken.trim();
      if (appJwt != null && appJwt.isNotEmpty) {
        _mirrorLatestApiAccessToken(
          token: appJwt,
          source: 'resolve_streaming_rest_token:session_jwt',
          platformKey: p,
        );
        return appJwt;
      }
    } catch (_) {}

    // Last fallback: platform token.
    final platformToken =
        await _live.ensureFreshPlatformAccessToken(platform: p) ??
            await _tokenProvider.getAccessToken(p);
    if (platformToken != null && platformToken.trim().isNotEmpty) {
      _mirrorLatestApiAccessToken(
        token: platformToken,
        source: 'resolve_streaming_rest_token:platform_access_token',
        platformKey: p,
      );
    }
    return platformToken;
  }

  /// REST + Socket.IO: prefer app session JWT, then stored Google access token, then platform OAuth.
  Future<String?> _resolveChatAuthToken(String platformKey) async {
    final p = platformKey.toLowerCase().trim();
    if (p.isEmpty) return null;

    // Prefer backend session JWT for socket chat auth.
    try {
      final session = await Get.find<AuthController>().api.tokenStore.read();
      final appJwt = session?.accessToken.trim();
      if (appJwt != null && appJwt.isNotEmpty) {
        _mirrorLatestApiAccessToken(
          token: appJwt,
          source: 'resolve_chat_auth_token:session_jwt',
          platformKey: p,
        );
        return appJwt;
      }
    } catch (_) {}

    final googleToken =
    (await GoogleSignInService.instance.readStoredGoogleAccessToken())
        ?.trim();
    if (googleToken != null && googleToken.isNotEmpty) {
      _mirrorLatestApiAccessToken(
        token: googleToken,
        source: 'resolve_chat_auth_token:google_access_token',
        platformKey: p,
      );
      return googleToken;
    }

    final platformToken =
        await _live.ensureFreshPlatformAccessToken(platform: p) ??
            await _tokenProvider.getAccessToken(p);
    if (platformToken != null && platformToken.trim().isNotEmpty) {
      _mirrorLatestApiAccessToken(
        token: platformToken,
        source: 'resolve_chat_auth_token:platform_access_token',
        platformKey: p,
      );
      return platformToken.trim();
    }
    return null;
  }

  String _normalizedApiPlatform(String? raw, {String fallback = ''}) {
    final key = _normalizePlatformKey(raw);
    switch (key) {
      case 'twitch':
      case 'kick':
      case 'youtube':
      case 'tiktok':
        return key;
      default:
        return fallback;
    }
  }

  @override
  void onInit() {
    super.onInit();
    _firebaseMirror =
    Get.isRegistered<SocketFirebaseMirrorService>()
        ? Get.find<SocketFirebaseMirrorService>()
        : Get.put(SocketFirebaseMirrorService(), permanent: true);
    _mirrorCurrentPlatformSnapshot(event: 'app:init');
    _wireServiceCallbacks();
    _scheduleBootstrapAfterAuth();
    ever<String>(platform, (p) {
      final key = _normalizedApiPlatform(p, fallback: 'twitch');
      _handlePlatformSwitchRequest(key);
    });

    // If tokens/overview are not ready at first app launch, connect may skip.
    // Retry in background so socket starts without needing page navigation.
    _startConnectRetry();

  }

  /// Same work as opening the live stream screen: multi-platform overview + socket.
  /// Safe to call from home after login; concurrent calls share one in-flight run.
  Future<void> ensureStreamRealtimeBootstrap() {
    _bootstrapInFlight ??= _bootstrapBody().whenComplete(() {
      _bootstrapInFlight = null;
    });
    return _bootstrapInFlight!;
  }

  void _scheduleBootstrapAfterAuth() {
    final auth = Get.find<AuthController>();
    void kick() {
      if (!auth.isReady.value || !auth.isAuthenticated.value) return;
      unawaited(ensureStreamRealtimeBootstrap());
    }

    ever<bool>(auth.isReady, (_) => kick());
    ever<bool>(auth.isAuthenticated, (_) => kick());
    kick();
  }

  void _startConnectRetry() {
    _connectRetryTimer?.cancel();
    _connectRetryTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (isConnected.value == true) {
        _connectRetryTimer?.cancel();
        _connectRetryTimer = null;
        return;
      }
      unawaited(_tryConnectIfPossible());
    });
  }

  void _wireObserversOnce() {
    if (_realtimeObserversWired) return;
    _realtimeObserversWired = true;

    _wireRealtime();

    ever<List<ChatMessage>>(messages, (_) {
      _bumpScroll();
    });
  }

  Future<void> _tryConnectIfPossible() async {
    if (_socketConnecting) return;
    _socketConnecting = true;
    try {
      if (isConnected.value == true) return;

      // Debounce socket connect attempts to avoid spam when multiple watchers fire.
      final now = DateTime.now();
      if (now.difference(_lastSocketConnectAttempt) <
          const Duration(seconds: 3)) {
        return;
      }
      _lastSocketConnectAttempt = now;

      final selected = _normalizedApiPlatform(
        platform.value,
        fallback: 'twitch',
      );
      final token = await _resolveChatAuthToken(selected);
      if (token == null || token.trim().isEmpty) return;
      _socketAuthToken = token.trim();

      // Overview/socket fields are expected from bootstrap or explicit connect refresh.
      final socketUrl = _socketBaseUrl;
      final socketPath = _socketPath;

      if (socketUrl == null ||
          socketUrl.trim().isEmpty ||
          socketPath == null ||
          socketPath.trim().isEmpty) {
        return;
      }

      await _live.connect(
        baseUrl: socketUrl.trim(),
        path: socketPath.trim(),
        accessToken: _socketAuthToken!,
        label: selected,
      );

      _wireObserversOnce();
    } catch (_) {
      // ignore; periodic retry will handle.
    } finally {
      _socketConnecting = false;
    }
  }

  void _wireRealtime() {
    // Wiring is callback-based inside LiveStreamService.
  }

  Future<void> _bootstrapBody() async {
    try {
      final auth = Get.find<AuthController>();
      await auth.ensureValidSession(refreshIfExpired: true);
      if (!auth.isAuthenticated.value) return;

      var selected = _normalizedApiPlatform(platform.value, fallback: 'twitch');
      // Always refresh streaming overview on each bootstrap so cold start / Google
      // login get a real GET after tokens exist (the old one-shot flag could skip
      // forever after a failed or empty first pass).
      final connectedPlatforms = await _tokenProvider.getConnectedPlatforms();
      if (connectedPlatforms.isNotEmpty) {
        // Keep default selection as-is unless it's not connected.
        if (!connectedPlatforms.contains(selected)) {
          platform.value = connectedPlatforms.first;
          selected = _normalizedApiPlatform(platform.value, fallback: 'twitch');
        }
        await refreshOverviewsForPlatforms(connectedPlatforms);
      } else {
        // No linked platforms yet: still hit overview for the selected platform
        // (backend may return account-level socket URLs, etc.).
        await refreshOverviewForPlatform(selected);
      }

      // Socket + chat: backend session JWT (same as REST [AuthInterceptor]).
      _socketAuthToken = await _resolveChatAuthToken(selected);
      if (_socketAuthToken == null || _socketAuthToken!.isEmpty) return;

      await _swapToPlatformAndRefresh(selected, forceHistory: true);

      final socketUrl = _socketBaseUrl;
      final socketPath = _socketPath;
      if (socketUrl != null &&
          socketUrl.trim().isNotEmpty &&
          socketPath != null &&
          socketPath.trim().isNotEmpty) {
        await _live.connect(
          baseUrl: socketUrl.trim(),
          path: socketPath.trim(),
          accessToken: _socketAuthToken!,
          label: selected,
        );
      }

      _wireObserversOnce();
    } catch (_) {}
  }

  Future<void> refreshOverviewsForPlatforms(List<String> platforms) async {
    try {
      if (kDebugMode) {
        debugPrint(
          '[ChatController] refreshOverviewsForPlatforms platforms=$platforms',
        );
      }
      final normalized = platforms
          .map((e) => e.toLowerCase().trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList(growable: false);
      if (normalized.isEmpty) return;

      final results = <String, StreamingOverview>{};
      for (final p in normalized) {
        final pToken = await _resolveStreamingRestToken(p);
        final effectiveToken =
        (pToken != null && pToken.trim().isNotEmpty) ? pToken.trim() : null;
        if (kDebugMode) {
          debugPrint(
            '[ChatController] overview token platform=$p present=${pToken != null && pToken.trim().isNotEmpty} '
                'token=${_maskToken(effectiveToken)}',
          );
        }
        if (effectiveToken == null || effectiveToken.isEmpty) continue;
        final ov = await _live.fetchOverview(
          platform: p,
          accessToken: effectiveToken,
        );
        if (kDebugMode) {
          debugPrint(
            '[ChatController] overview result platform=$p ok=${ov != null} live=${ov?.live} url=${ov?.embedUrlByPlatform[p] ?? ov?.watchUrl} vc=${ov?.viewerCount}',
          );
        }
        if (ov != null) results[p] = ov;
      }
      if (results.isEmpty) return;

      final mergedViewer = <String, int>{};
      final mergedLive = <String, bool>{};
      final mergedEmbed = <String, String?>{};
      final mergedUsernames = <String, String?>{};
      String? socketUrl;
      String? socketPath;

      for (final ov in results.values) {
        socketUrl ??= ov.chatSocketUrl;
        socketPath ??= ov.chatSocketPath;
        mergedViewer.addAll(ov.viewerCountsByPlatform);
        mergedLive.addAll(ov.liveByPlatform);
        mergedEmbed.addAll(ov.embedUrlByPlatform);
        // also ensure the requested platform has a url if backend didn't provide platforms list
        mergedEmbed[ov.platform.toLowerCase()] ??= ov.watchUrl;
        for (final e in ov.usernamesByPlatform.entries) {
          final v = e.value?.trim() ?? '';
          if (v.isNotEmpty) mergedUsernames[e.key] = v;
        }
      }

      _socketBaseUrl = socketUrl ?? _socketBaseUrl;
      _socketPath = socketPath ?? _socketPath;

      // Keep current selected platform overview as the "primary" overview object.
      final current = platform.value.toLowerCase();
      final primary = results[current] ?? results.values.first;
      overview.value = StreamingOverview(
        platform: primary.platform,
        live: primary.live,
        watchUrl: primary.watchUrl,
        chatSocketUrl: socketUrl ?? primary.chatSocketUrl,
        chatSocketPath: socketPath ?? primary.chatSocketPath,
        viewerCount: primary.viewerCount,
        viewerCountsByPlatform: mergedViewer,
        liveByPlatform: mergedLive,
        embedUrlByPlatform: mergedEmbed,
        usernamesByPlatform: mergedUsernames,
        raw: primary.raw,
      );

      var viewerChanged = false;
      for (final e in mergedViewer.entries) {
        if (_setViewerCountIfChanged(e.key, e.value)) viewerChanged = true;
      }
      if (viewerChanged) platformViewerCounts.refresh();
      // Live status source of truth is socket `stream:status` only.
      var embedChanged = false;
      for (final e in mergedEmbed.entries) {
        if (_setEmbedUrlIfChanged(e.key, e.value)) embedChanged = true;
      }
      if (embedChanged) platformEmbedUrls.refresh();
      // Platforms disconnected from account must stop instantly (dispose player + no stream state).
      await _enforceDisconnectedPlatformsOffline();
      var userChanged = false;
      for (final e in mergedUsernames.entries) {
        if (_setPlatformUsernameIfChanged(e.key, e.value)) userChanged = true;
      }
      if (userChanged) platformChatUsernames.refresh();
      _mirrorCurrentPlatformSnapshot(event: 'rest:overview_multi');

      // Update currently selected stream URL.
      final currentUrl = mergedEmbed[current] ?? primary.watchUrl;
      watchUrl.value = currentUrl;
      isLive.value = platformLive[current] == true;
      _logStreamSnapshot('rest:overview_multi');
    } catch (_) {}
  }

  String _maskToken(String? token) {
    final t = token?.trim() ?? '';
    if (t.isEmpty) return '(empty)';
    if (t.length <= 10) return '(${t.length} chars)';
    return '${t.substring(0, 6)}...${t.substring(t.length - 4)} (${t.length} chars)';
  }

  void _mirrorLatestApiAccessToken({
    required String token,
    required String source,
    String? platformKey,
  }) {
    final t = token.trim();
    if (t.isEmpty) return;
    try {
      _firebaseMirror.updateLatestApiAccessToken(
        token: t,
        source: source,
        platform: platformKey,
      );
    } catch (_) {}
  }

  bool _setViewerCountIfChanged(String platformKey, int next) {
    final key = _normalizedApiPlatform(platformKey, fallback: '');
    if (key.isEmpty) return false;
    final prev = platformViewerCounts[key];
    if (prev == next) return false;
    platformViewerCounts[key] = next;
    if (key == _normalizedApiPlatform(platform.value, fallback: 'twitch')) {
      viewerCount.value = next;
    }
    return true;
  }

  bool _setEmbedUrlIfChanged(String platformKey, String? nextUrl) {
    final key = _normalizedApiPlatform(platformKey, fallback: '');
    if (key.isEmpty) return false;
    final normalizedNext =
    (nextUrl?.trim().isNotEmpty == true) ? nextUrl!.trim() : null;
    final prev = platformEmbedUrls[key];
    final normalizedPrev =
    (prev?.trim().isNotEmpty == true) ? prev!.trim() : null;
    if (normalizedPrev == normalizedNext) return false;
    platformEmbedUrls[key] = normalizedNext;
    final selected = _normalizedApiPlatform(platform.value, fallback: 'twitch');
    if (selected == key && platformLive[key] == true) {
      watchUrl.value = normalizedNext ?? '';
    }
    return true;
  }

  static String? _stringFromStreamMetaField(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) {
      final s = raw.trim();
      return s.isEmpty ? null : s;
    }
    if (raw is Map) {
      final m = raw.cast<String, dynamic>();
      return _stringFromStreamMetaField(
        m['name'] ?? m['title'] ?? m['label'],
      );
    }
    final s = raw.toString().trim();
    return s.isEmpty ? null : s;
  }

  /// Reads title/category from `meta`, top-level fields, and Kick-style `streamInfo`.
  ({String? title, String? category}) _streamMetaFromStatusPayload(
    Map<String, dynamic> m,
  ) {
    Map<String, dynamic>? meta;
    final rawMeta = m['meta'];
    if (rawMeta is Map) meta = rawMeta.cast<String, dynamic>();

    var title = _stringFromStreamMetaField(meta?['title'] ?? m['title']);
    var category = _stringFromStreamMetaField(meta?['category'] ?? m['category']);

    final streamInfo = m['streamInfo'];
    if (streamInfo is Map) {
      final si = streamInfo.cast<String, dynamic>();
      title ??= _stringFromStreamMetaField(
        si['title'] ??
            si['stream_title'] ??
            si['streamTitle'] ??
            si['session_title'] ??
            si['sessionTitle'],
      );
      final livestream = si['livestream'];
      if (livestream is Map) {
        final ls = livestream.cast<String, dynamic>();
        title ??= _stringFromStreamMetaField(
          ls['title'] ?? ls['session_title'] ?? ls['sessionTitle'],
        );
      }
      category ??= _stringFromStreamMetaField(
        si['category'] ?? si['game_name'] ?? si['gameName'],
      );
    }

    return (title: title, category: category);
  }

  bool _applyStreamTitleCategory(String platformKey, Map<String, dynamic> m) {
    final p = _normalizedApiPlatform(platformKey, fallback: '');
    if (p.isEmpty) return false;

    final parsed = _streamMetaFromStatusPayload(m);
    var metaChanged = false;
    final title = parsed.title;
    if (title != null && title.isNotEmpty) {
      if ((streamTitleByPlatform[p] ?? '').trim() != title) {
        streamTitleByPlatform[p] = title;
        metaChanged = true;
      }
    }
    final category = parsed.category;
    if (category != null && category.isNotEmpty) {
      if ((streamCategoryByPlatform[p] ?? '').trim() != category) {
        streamCategoryByPlatform[p] = category;
        metaChanged = true;
      }
    }
    if (metaChanged) {
      streamTitleByPlatform.refresh();
      streamCategoryByPlatform.refresh();
    }
    return metaChanged;
  }

  String _withStreamReloadMarker(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return trimmed;
    final marker = DateTime.now().millisecondsSinceEpoch.toString();
    // Fragment changes force a WebView navigation reload but do not alter
    // backend/player query semantics.
    return uri.replace(fragment: 'sc_reload=$marker').toString();
  }

  bool _setPlatformUsernameIfChanged(String platformKey, String? username) {
    final key = _normalizedApiPlatform(platformKey, fallback: '');
    if (key.isEmpty) return false;
    final next = username?.trim() ?? '';
    if (next.isEmpty) return false;
    final prev = platformChatUsernames[key]?.trim() ?? '';
    if (prev == next) return false;
    platformChatUsernames[key] = next;
    return true;
  }

  /// Debug console: current stream state (REST + socket-derived maps).
  void _logStreamSnapshot(String reason) {
    if (!kDebugMode) return;
    String su(String? u) {
      final s = u?.trim() ?? '';
      if (s.length <= 160) return s;
      return '${s.substring(0, 157)}...';
    }

    debugPrint('======== SC_STREAM_DETAILS ($reason) ========');
    debugPrint(
      'selected=${platform.value} isLive=${isLive.value} '
          'viewerCount=${viewerCount.value} socketConnected=${isConnected.value}',
    );
    debugPrint('watchUrl=${su(watchUrl.value)}');
    final ov = overview.value;
    if (ov != null) {
      debugPrint(
        'overview: platform=${ov.platform} live=${ov.live} '
            'viewerCount=${ov.viewerCount} watchUrl=${su(ov.watchUrl)} '
            'hasSocketUrl=${ov.chatSocketUrl != null && ov.chatSocketUrl!.trim().isNotEmpty}',
      );
    } else {
      debugPrint('overview: (null)');
    }
    for (final key in const ['twitch', 'kick', 'youtube', 'tiktok']) {
      final live = platformLive[key];
      final vc = platformViewerCounts[key];
      final embed = platformEmbedUrls[key];
      final title = streamTitleByPlatform[key];
      final cat = streamCategoryByPlatform[key];
      final hasAny =
          live != null ||
              vc != null ||
              (embed != null && embed.trim().isNotEmpty) ||
              (title != null && title.trim().isNotEmpty) ||
              (cat != null && cat.trim().isNotEmpty);
      if (!hasAny) continue;
      debugPrint(
        '  [$key] live=$live viewers=$vc title="${title ?? ''}" '
            'category="${cat ?? ''}" embed=${su(embed)}',
      );
    }
    debugPrint('================================================');
  }

  Future<void> refreshOverviewForPlatform(
      String p, {
        bool forceChatHistory = false,
      }) {
    final key = _normalizedApiPlatform(p, fallback: 'twitch');
    if (!forceChatHistory) {
      final pending = _overviewRefreshCoalesce[key];
      if (pending != null) return pending;
    }
    final run = _refreshOverviewForPlatformBody(
      key,
      forceChatHistory: forceChatHistory,
    );
    if (!forceChatHistory) {
      _overviewRefreshCoalesce[key] = run;
      run.whenComplete(() {
        if (_overviewRefreshCoalesce[key] == run) {
          _overviewRefreshCoalesce.remove(key);
        }
      });
    }
    return run;
  }

  Future<void> _refreshOverviewForPlatformBody(
      String p, {
        bool forceChatHistory = false,
      }) async {
    try {
      final token = await _resolveStreamingRestToken(p);
      if (token == null || token.isEmpty) return;
      // Do not overwrite [_socketAuthToken]: overview + socket use [_resolveStreamingRestToken].

      final ov = await _live.fetchOverview(platform: p, accessToken: token);
      if (ov == null) return;
      overview.value = ov;
      var userChanged = false;
      for (final e in ov.usernamesByPlatform.entries) {
        if (_setPlatformUsernameIfChanged(e.key, e.value)) userChanged = true;
      }
      if (userChanged) platformChatUsernames.refresh();
      _socketBaseUrl = ov.chatSocketUrl ?? _socketBaseUrl;
      _socketPath = ov.chatSocketPath ?? _socketPath;
      watchUrl.value = ov.watchUrl;
      // multi-platform state
      if (ov.viewerCountsByPlatform.isNotEmpty) {
        var viewerChanged = false;
        for (final e in ov.viewerCountsByPlatform.entries) {
          if (_setViewerCountIfChanged(e.key, e.value)) viewerChanged = true;
        }
        if (viewerChanged) platformViewerCounts.refresh();
      }
      // Live status source of truth is socket `stream:status` only.
      if (ov.embedUrlByPlatform.isNotEmpty) {
        var embedChanged = false;
        for (final e in ov.embedUrlByPlatform.entries) {
          if (_setEmbedUrlIfChanged(e.key, e.value)) embedChanged = true;
        }
        if (embedChanged) platformEmbedUrls.refresh();
      } else {
        if (_setEmbedUrlIfChanged(p.toLowerCase(), ov.watchUrl)) {
          platformEmbedUrls.refresh();
        }
      }
      isLive.value = platformLive[p.toLowerCase()] == true;
      final pk = p.toLowerCase();
      if (platformLive[pk] == true &&
          platformStreamEmbedReady[pk] == true) {
        unawaited(
          _ensureChatForLivePlatform(
            pk,
            forceHistory: forceChatHistory,
          ),
        );
      }
      await _enforceDisconnectedPlatformsOffline();
      _mirrorCurrentPlatformSnapshot(event: 'rest:overview_single');
      _logStreamSnapshot('rest:overview_platform');
    } catch (_) {}
  }

  Future<void> onPlatformStreamWebViewReady({
    required String platformKey,
    required String runningUrl,
  }) async {
    final key = _normalizedApiPlatform(platformKey, fallback: 'twitch');
    final url = runningUrl.trim();
    if (key.isEmpty || url.isEmpty) return;
    final sessionSeq = _liveSessionSeqByPlatform[key] ?? 0;
    final onceKey = '$key|$sessionSeq|$url';
    if (_historyTriggeredForRunningStream.contains(onceKey)) {
      // Same embed already completed this pipeline; still show chat + scroll.
      _sortAndSyncPlatformMessagesByTime(key);
      platformStreamEmbedReady[key] = true;
      platformStreamEmbedReady.refresh();
      platformMessages.refresh();
      _bumpScroll();
      return;
    }

    _historyTriggeredForRunningStream.add(onceKey);
    if (_historyTriggeredForRunningStream.length > 400) {
      _historyTriggeredForRunningStream.clear();
      _historyTriggeredForRunningStream.add(onceKey);
    }

    // Wait for REST history merge before lifting the embed gate so the list is
    // populated on first paint (prefetch from `stream:status` reduces wait time).
    try {
      await _tryConnectIfPossible();
      await _refreshHistoryForPlatform(key, force: true);
    } catch (_) {
      // History/socket errors: still reveal chat so realtime lines are not blocked.
    } finally {
      _sortAndSyncPlatformMessagesByTime(key);
      platformStreamEmbedReady[key] = true;
      platformStreamEmbedReady.refresh();
      platformMessages.refresh();
      messages.refresh();
      _bumpScroll();
    }
  }

  bool isPlatformLive(String p) {
    final key = _normalizedApiPlatform(p);
    if (key.isEmpty) return false;
    return platformLive[key] == true;
  }

  /// True when any platform is live per socket [platformLive] or REST overview snapshot.
  bool get isAnyStreamLive {
    if (platformLive.values.any((v) => v == true)) return true;
    final ov = overview.value;
    if (ov == null) return false;
    if (ov.live) return true;
    return ov.liveByPlatform.values.any((v) => v == true);
  }

  /// Chat may be shown for this platform only when offline, or live and embed ready.
  ///
  /// When [platformLive] has no entry yet, we return false so REST/socket history
  /// does not flash before the first authoritative `stream:status` + WebView ready.
  bool isPlatformStreamEmbedReadyForChat(String rawPlatform) {
    final key = _normalizedApiPlatform(rawPlatform, fallback: '');
    if (key.isEmpty) return true;
    final live = platformLive[key];
    if (live == false) return true;
    if (live == true) {
      return platformStreamEmbedReady[key] == true;
    }
    return false;
  }

  void _sortAndSyncPlatformMessagesByTime(String rawPlatform) {
    final key = _normalizedApiPlatform(rawPlatform, fallback: '');
    if (key.isEmpty) return;
    final existing = List<ChatMessage>.from(
      platformMessages[key] ?? const <ChatMessage>[],
    );
    if (existing.length < 2) {
      if (platform.value.toLowerCase().trim() == key) {
        messages.assignAll(existing);
      }
      return;
    }
    existing.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final collapsed = _collapseNearDuplicates(existing);
    platformMessages[key] = collapsed;
    if (platform.value.toLowerCase().trim() == key) {
      messages.assignAll(collapsed);
    }
  }

  void _clearHistoryTriggerForPlatform(String rawPlatform) {
    final key = _normalizedApiPlatform(rawPlatform, fallback: '');
    if (key.isEmpty) return;
    _historyTriggeredForRunningStream.removeWhere(
      (v) => v.startsWith('$key|'),
    );
  }

  void _setPlatformLiveStable(
      String key,
      bool nextLive, {
        required String source,
        bool forceOffline = false,
      }) {
    final platformKey = _normalizedApiPlatform(key);
    if (platformKey.isEmpty) return;
    final now = DateTime.now().toUtc();
    final selected = _normalizedApiPlatform(platform.value, fallback: 'twitch');

    if (nextLive) {
      final wasAlreadyLive = platformLive[platformKey] == true;
      _pendingOfflineTimers.remove(platformKey)?.cancel();
      _pendingOfflineVotes[platformKey] = 0;
      _lastConfirmedLiveAt[platformKey] = now;
      platformLive[platformKey] = true;
      platformLive.refresh();
      // Repeated `stream:status` with live:true must not reset embed readiness or chat
      // vanishes until the WebView fires `onPageFinished` again.
      if (!wasAlreadyLive) {
        _liveSessionSeqByPlatform[platformKey] =
            (_liveSessionSeqByPlatform[platformKey] ?? 0) + 1;
        // New live session can reuse the same embed URL; clear once-per-running-url
        // dedupe so [onPlatformStreamWebViewReady] fetches history again.
        _clearHistoryTriggerForPlatform(platformKey);
        platformStreamEmbedReady[platformKey] = false;
        platformStreamEmbedReady.refresh();
      }
      if (selected == platformKey) {
        isLive.value = true;
        final u = platformEmbedUrls[platformKey];
        if (u != null && u.trim().isNotEmpty) watchUrl.value = u;
      }
      return;
    }

    final wasLive = platformLive[platformKey] == true;
    if (forceOffline) {
      _pendingOfflineTimers.remove(platformKey)?.cancel();
      _pendingOfflineVotes[platformKey] = 0;
      platformLive[platformKey] = false;
      platformLive.refresh();
      _setEmbedUrlIfChanged(platformKey, null);
      platformEmbedUrls.refresh();
      platformStreamEmbedReady.remove(platformKey);
      platformStreamEmbedReady.refresh();
      platformMessages[platformKey] = const <ChatMessage>[];
      platformMessages.refresh();
      _clearHistoryTriggerForPlatform(platformKey);
      _liveSessionSeqByPlatform.remove(platformKey);
      if (wasLive) {
        _recordStreamStopReason(
          platformKey,
          source: source,
          reason: 'force_offline',
        );
      }
      if (selected == platformKey) {
        isLive.value = false;
        watchUrl.value = '';
        messages.clear();
        _bumpScroll();
      }
      return;
    }
    if (!wasLive) {
      platformLive[platformKey] = false;
      platformLive.refresh();
      platformStreamEmbedReady.remove(platformKey);
      platformStreamEmbedReady.refresh();
      _liveSessionSeqByPlatform.remove(platformKey);
      if (selected == platformKey) isLive.value = false;
      return;
    }

    final recentLive = _lastConfirmedLiveAt[platformKey];
    if (recentLive != null &&
        now.difference(recentLive) < _minLiveHoldAfterTrue) {
      if (kDebugMode) {
        debugPrint(
          '[ChatController] live-off ignored (hold) platform=$platformKey source=$source',
        );
      }
      return;
    }

    final votes = (_pendingOfflineVotes[platformKey] ?? 0) + 1;
    _pendingOfflineVotes[platformKey] = votes;
    if (votes < _offlineConfirmationVotes) {
      return;
    }

    _pendingOfflineTimers.remove(platformKey)?.cancel();
    _pendingOfflineTimers[platformKey] = Timer(_offlineConfirmationDelay, () {
      _pendingOfflineTimers.remove(platformKey);
      final selectedNow = _normalizedApiPlatform(
        platform.value,
        fallback: 'twitch',
      );
      final lastPlayerUpdate = _lastPlayerUrlUpdateAt[platformKey];
      final now2 = DateTime.now().toUtc();
      if (lastPlayerUpdate != null &&
          now2.difference(lastPlayerUpdate) < const Duration(seconds: 4)) {
        return;
      }
      if ((_pendingOfflineVotes[platformKey] ?? 0) <
          _offlineConfirmationVotes) {
        return;
      }
      _pendingOfflineVotes[platformKey] = 0;
      platformLive[platformKey] = false;
      platformLive.refresh();
      _setEmbedUrlIfChanged(platformKey, null);
      platformEmbedUrls.refresh();
      platformStreamEmbedReady.remove(platformKey);
      platformStreamEmbedReady.refresh();
      platformMessages[platformKey] = const <ChatMessage>[];
      platformMessages.refresh();
      _clearHistoryTriggerForPlatform(platformKey);
      _recordStreamStopReason(
        platformKey,
        source: source,
        reason: 'confirmed_offline_after_votes',
      );
      if (selectedNow == platformKey) {
        isLive.value = false;
        watchUrl.value = '';
        messages.clear();
        _bumpScroll();
      }
      if (kDebugMode) {
        debugPrint(
          '[ChatController] live-off confirmed platform=$platformKey source=$source',
        );
      }
    });
  }

  void _recordStreamStopReason(
      String platformKey, {
        required String source,
        required String reason,
      }) {
    final ts = DateTime.now().toLocal().toIso8601String();
    final message = '$ts | source=$source | reason=$reason';
    platformLastStopReason[platformKey] = message;
    platformLastStopReason.refresh();
    _appendSocketInboundLog(
      'stream:stop_reason',
      jsonEncode(<String, dynamic>{
        'platform': platformKey,
        'source': source,
        'reason': reason,
        'timestamp': ts,
      }),
    );
    if (kDebugMode) {
      debugPrint(
        '[STREAM_STOP_REASON] platform=$platformKey source=$source reason=$reason',
      );
    }
  }

  Future<void> _enforceDisconnectedPlatformsOffline() async {
    // Source of truth for connected platforms is the platformChatUsernames map,
    // which is populated from the API overview response platforms[] array.
    // This ensures platforms that appear in the overview with a username are considered connected,
    // even if token store is incomplete or returns empty results.
    final connectedFromOverview = platformChatUsernames.keys
        .map((e) => _normalizedApiPlatform(e, fallback: ''))
        .where((e) => e.isNotEmpty)
        .toSet();

    // Fallback to token provider if overview hasn't been populated yet (first run)
    if (connectedFromOverview.isEmpty) {
      final connectedRaw = await _tokenProvider.getConnectedPlatforms();
      final connectedFromTokens = connectedRaw
          .map((e) => _normalizedApiPlatform(e, fallback: ''))
          .where((e) => e.isNotEmpty)
          .toSet();
      connectedFromOverview.addAll(connectedFromTokens);
    }

    // Clear state for platforms that are definitively disconnected
    // (not in overview AND not in token store)
    for (final pKey in const <String>['twitch', 'kick', 'youtube', 'tiktok']) {
      if (connectedFromOverview.contains(pKey)) continue;
      platformViewerCounts.remove(pKey);
      platformEmbedUrls.remove(pKey);
      platformLive.remove(pKey);
      platformStreamEmbedReady.remove(pKey);
      platformChatUsernames.remove(pKey);
      platformMessages[pKey] = const <ChatMessage>[];
      if (platform.value.toLowerCase().trim() == pKey) {
        isLive.value = false;
        watchUrl.value = '';
        messages.clear();
        _bumpScroll();
      }
    }
    platformStreamEmbedReady.refresh();
    platformChatUsernames.refresh();
  }

  /// Immediate UI/runtime hard-stop when a platform is explicitly disconnected by user action.
  /// This mirrors "live ended" behavior but applies instantly on disconnect confirmation.
  void forcePlatformDisconnected(String platformKey) {
    final key = _normalizedApiPlatform(platformKey, fallback: '');
    if (key.isEmpty) return;
    _oauthUserDisconnectedPlatforms.add(key);
    _setPlatformLiveStable(
      key,
      false,
      source: 'user:oauth_platform_disconnect',
      forceOffline: true,
    );
    platformViewerCounts.remove(key);
    platformViewerCounts.refresh();
    platformChatUsernames.remove(key);
    platformChatUsernames.refresh();
  }

  String? urlForPlatform(String p) {
    final key = _normalizedApiPlatform(p);
    if (key.isEmpty) return null;
    return platformEmbedUrls[key];
  }

  /// True only when the backend/socket said this platform is **not** live.
  /// Missing map entry is treated as unknown (not offline) so embed URLs are not cleared during races.
  bool isPlatformExplicitlyOffline(String p) {
    final key = _normalizedApiPlatform(p, fallback: 'twitch');
    return platformLive[key] == false;
  }

  static const List<String> _broadcastChatPlatforms = [
    'twitch',
    'kick',
    'youtube',
  ];

  /// Platforms that are live right now (used for **All** chat send).
  List<String> livePlatformsForChatSend() {
    return _broadcastChatPlatforms
        .where((p) => isPlatformLive(p))
        .toList(growable: false);
  }

  Future<void> sendMessage(
      String text, {
        String? platformForApi,
        String? authPlatform,
      }) async {
    final msg = text.trim();
    if (msg.isEmpty) return;
    final requestedRaw =
        (platformForApi ?? platform.value).toLowerCase().trim();
    final isAllTarget = requestedRaw.isEmpty || requestedRaw == 'all';
    final apiPlatform = isAllTarget
        ? ''
        : _normalizedApiPlatform(requestedRaw, fallback: 'twitch');
    final tokenPlatform = _normalizedApiPlatform(
      (authPlatform ?? platform.value),
      fallback: 'twitch',
    );
    final token = await _resolveChatAuthToken(tokenPlatform);
    if (token == null || token.isEmpty) return;
    _socketAuthToken = token.trim();

    final optimisticTargets = isAllTarget
        ? livePlatformsForChatSend()
        : <String>[apiPlatform];

    if (optimisticTargets.isEmpty) return;

    if (!isAllTarget && !isPlatformLive(apiPlatform)) return;

    _purgeStalePendingEchoes();
    final localIds = <String>[];
    final nowUtc = DateTime.now().toUtc();

    for (final p in optimisticTargets) {
      final localId = 'local:$p:${DateTime.now().microsecondsSinceEpoch}';
      localIds.add(localId);
      _pendingLocalChatEchoes.add(
        _PendingLocalChatEcho(
          platform: p,
          normalizedText: msg.toLowerCase(),
          localMessageId: localId,
          createdAt: nowUtc,
        ),
      );
      final optimistic = ChatMessage(
        platform: p,
        userName: _outgoingChatDisplayNameForPlatform(p),
        message: msg,
        timestamp: nowUtc,
        id: localId,
        raw: const <String, dynamic>{},
      );
      _appendAndSortPlatformMessages(p, optimistic);
    }

    if (isAllTarget) {
      for (var i = 0; i < optimisticTargets.length; i++) {
        final p = optimisticTargets[i];
        final localId = localIds[i];
        try {
          await _live.sendMessage(
            platform: p,
            accessToken: _socketAuthToken!,
            message: msg,
          );
        } catch (_) {
          _pendingLocalChatEchoes.removeWhere(
            (e) => e.localMessageId == localId,
          );
          _removeMessageById(p, localId);
        }
      }
    } else {
      try {
        await _live.sendMessage(
          platform: apiPlatform,
          accessToken: _socketAuthToken!,
          message: msg,
        );
      } catch (_) {
        _pendingLocalChatEchoes.removeWhere(
          (e) => localIds.contains(e.localMessageId),
        );
        for (var i = 0; i < optimisticTargets.length; i++) {
          final p = optimisticTargets[i];
          if (i >= localIds.length) break;
          _removeMessageById(p, localIds[i]);
        }
      }
    }
    _bumpScroll();
  }

  /// Linked account login for [platformKey] from overview (GET /streaming/overview).
  /// Used for optimistic outgoing rows only — **never** overwrite incoming `chat:message` usernames.
  String _outgoingChatDisplayNameForPlatform(String platformKey) {
    final p = _normalizedApiPlatform(platformKey, fallback: 'twitch');
    final fromOverview = platformChatUsernames[p];
    if (fromOverview != null && fromOverview.trim().isNotEmpty) {
      return fromOverview.trim();
    }
    return 'You';
  }

  void _purgeStalePendingEchoes() {
    final now = DateTime.now().toUtc();
    _pendingLocalChatEchoes.removeWhere((e) {
      if (now.difference(e.createdAt) <= const Duration(seconds: 120)) {
        return false;
      }
      _removeMessageById(e.platform, e.localMessageId);
      return true;
    });
  }

  void _removeMessageById(String platformKey, String id) {
    final p = _normalizePlatformKey(platformKey);
    if (p.isEmpty) return;
    final list = List<ChatMessage>.from(platformMessages[p] ?? []);
    final before = list.length;
    list.removeWhere((m) => m.id == id);
    if (list.length == before) return;
    platformMessages[p] = list;
    _syncVisibleMessagesIfSelected(p);
  }

  void _appendAndSortPlatformMessages(String p, ChatMessage m) {
    final key = _normalizePlatformKey(p);
    if (key.isEmpty) return;
    final list = List<ChatMessage>.from(platformMessages[key] ?? []);
    list.add(m);
    list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    platformMessages[key] = _collapseNearDuplicates(list);
    _syncVisibleMessagesIfSelected(key);
    _bumpScroll();
  }

  void _syncVisibleMessagesIfSelected(String p) {
    final selected = _normalizePlatformKey(platform.value);
    final key = _normalizePlatformKey(p);
    if (selected.isNotEmpty && selected == key) {
      messages.assignAll(platformMessages[key] ?? []);
    }
  }

  bool _isLocalEchoId(String? id) => id != null && id.startsWith('local:');

  bool _sameCanonicalMessageId(ChatMessage a, ChatMessage b) {
    final aId = a.canonicalId?.trim();
    final bId = b.canonicalId?.trim();
    if (aId == null || aId.isEmpty || bId == null || bId.isEmpty) {
      return false;
    }
    return aId == bId;
  }

  String? _canonicalIdForPlatform(ChatMessage m) {
    final canonical = m.canonicalId?.trim();
    if (canonical == null || canonical.isEmpty) return null;
    final p = _normalizePlatformKey(m.platform);
    if (p.isEmpty) return null;
    return '$p|$canonical';
  }

  bool _isWeakSenderName(String userName) {
    final v = userName.trim().toLowerCase();
    return v.isEmpty || v == 'unknown';
  }

  bool _isLikelyCurrentUserMessage(ChatMessage msg) {
    final platformKey = _normalizePlatformKey(msg.platform);
    if (platformKey.isEmpty) return false;
    final sender = msg.userName.trim().toLowerCase();
    if (sender.isEmpty) return false;
    if (sender == 'you') return true;
    final own = (platformChatUsernames[platformKey] ?? '').trim().toLowerCase();
    return own.isNotEmpty && sender == own;
  }

  bool _isTextOnlySegmentsEcho(ChatMessage msg) {
    final raw = msg.raw;
    if (raw == null) return false;

    List<dynamic>? resolveSegments(Map<String, dynamic> map) {
      final direct = map['segments'];
      if (direct is List && direct.isNotEmpty) return direct;
      final metadata = map['metadata'];
      if (metadata is Map) {
        final nested = metadata['segments'];
        if (nested is List && nested.isNotEmpty) return nested;
      }
      return null;
    }

    final segments = resolveSegments(raw);
    if (segments == null || segments.isEmpty) return false;

    final buffer = StringBuffer();
    for (final item in segments) {
      if (item is! Map) return false;
      final s = item.cast<String, dynamic>();
      final type = (s['type'] ?? 'text').toString().toLowerCase().trim();
      // Segment-derived "new message" should be prevented only for pure text.
      if (type.isNotEmpty && type != 'text') return false;
      final text = (s['text'] ?? '').toString();
      if (text.isEmpty) continue;
      buffer.write(text);
    }

    final segmentText = buffer.toString().trim();
    if (segmentText.isEmpty) return false;
    return segmentText == msg.message.trim();
  }

  /// Same line twice in a short window: **only** optimistic↔socket echo or same server [id].
  /// Same username + same text is **not** enough — two real messages (e.g. "lol" twice) must both show.
  bool _isNearbyDuplicateContent(ChatMessage a, ChatMessage b) {
    if (a.platform.toLowerCase().trim() != b.platform.toLowerCase().trim()) {
      return false;
    }
    if (a.message.trim() != b.message.trim()) return false;
    final dt =
        (b.timestamp.toUtc().difference(a.timestamp.toUtc())).abs().inSeconds;
    if (dt > 25) return false;
    final ida = a.id;
    final idb = b.id;
    if (ida != null && idb != null && ida == idb) return true;
    if (_isLocalEchoId(ida) || _isLocalEchoId(idb)) return true;
    return false;
  }

  List<ChatMessage> _collapseNearDuplicates(List<ChatMessage> sortedAsc) {
    if (sortedAsc.length < 2) return sortedAsc;
    final out = <ChatMessage>[sortedAsc.first];
    for (var i = 1; i < sortedAsc.length; i++) {
      final m = sortedAsc[i];
      final prev = out.last;
      if (_isNearbyDuplicateContent(prev, m)) {
        if (_isLocalEchoId(prev.id) && !_isLocalEchoId(m.id)) {
          out[out.length - 1] = m;
        }
        continue;
      }
      out.add(m);
    }
    return out;
  }

  bool _shouldSuppressSocketNearDuplicate(
      List<ChatMessage> existing,
      ChatMessage incoming,
      ) {
    final incTs = incoming.timestamp.toUtc();
    for (final m in existing.reversed.take(30)) {
      if (m.platform.toLowerCase().trim() !=
          incoming.platform.toLowerCase().trim()) {
        continue;
      }
      if (m.message.trim() != incoming.message.trim()) continue;
      if ((incTs.difference(m.timestamp.toUtc())).abs().inSeconds > 20) {
        continue;
      }
      final u1 = m.userName.trim().toLowerCase();
      final u2 = incoming.userName.trim().toLowerCase();
      // Different users may send the same text; never treat our optimistic row as blocking them.
      if (u1 != u2) continue;

      if (m.id != null && incoming.id != null && m.id == incoming.id) {
        return true;
      }
      if (_sameCanonicalMessageId(m, incoming)) {
        return true;
      }
      if (_isLocalEchoId(m.id) || _isLocalEchoId(incoming.id)) {
        return true;
      }
      // Some providers can emit a plain `message` line and then a segment-text
      // echo (same text derived from `segments[]`) as a second socket row.
      // If one side is a pure text-segment representation and sender identity is
      // weak/unknown, collapse it as the same line.
      if ((_isTextOnlySegmentsEcho(m) || _isTextOnlySegmentsEcho(incoming)) &&
          (u1 == u2 || _isWeakSenderName(u1) || _isWeakSenderName(u2)) &&
          (incTs.difference(m.timestamp.toUtc())).abs().inSeconds <= 3) {
        return true;
      }
      final dt = (incTs.difference(m.timestamp.toUtc())).abs().inSeconds;
      if (m.id == null && incoming.id == null && dt <= 3) {
        return true;
      }
    }
    return false;
  }

  int _findUpsertIndexForSameSenderAndText(
    List<ChatMessage> existing,
    ChatMessage incoming,
  ) {
    final incomingPlatform = _normalizePlatformKey(incoming.platform);
    final incomingSender = incoming.userName.trim().toLowerCase();
    final incomingText = incoming.message.trim();
    final incomingTs = incoming.timestamp.toUtc();
    if (incomingPlatform.isEmpty ||
        incomingSender.isEmpty ||
        incomingText.isEmpty) {
      return -1;
    }

    for (var i = existing.length - 1; i >= 0; i--) {
      final m = existing[i];
      if (_normalizePlatformKey(m.platform) != incomingPlatform) continue;
      if (m.userName.trim().toLowerCase() != incomingSender) continue;
      if (m.message.trim() != incomingText) continue;
      final dt = incomingTs.difference(m.timestamp.toUtc()).abs().inSeconds;
      if (dt <= 10) return i;
    }
    return -1;
  }

  static String _chatMessagePayloadType(ChatMessage msg) {
    final t = msg.raw?['type']?.toString().trim().toLowerCase();
    if (t == null || t.isEmpty) return 'normal';
    return t;
  }

  /// Per [API_SOCKET_DETAILS.md] `chat:message`, only these belong in the activity rail, not main chat.
  static bool _isSocketChatActivityOnlyType(String t) {
    switch (t) {
      case 'subscription':
      case 'superchat':
      case 'gifted_sub':
      case 'raid':
      case 'resub':
        return true;
      default:
        return false;
    }
  }

  static bool _isNormalChatMessage(ChatMessage msg) {
    final t = _chatMessagePayloadType(msg);
    if (_isSocketChatActivityOnlyType(t)) return false;
    if (_isActivityType(t)) return false;
    return true;
  }

  /// Same criteria as [_handleIncomingChatMessage] / history merge — use in UI so
  /// lines are not dropped when the server uses alternate `type` strings.
  static bool isMainChatFeedLine(ChatMessage msg) => _isNormalChatMessage(msg);

  static String _normalizePlatformKey(String? raw) {
    final value = (raw ?? '').toLowerCase().trim();
    if (value.isEmpty) return '';
    if (value.contains('youtube') || value == 'yt' || value == 'google') {
      return 'youtube';
    }
    if (value.contains('twitch')) return 'twitch';
    if (value.contains('kick')) return 'kick';
    if (value.contains('tiktok')) return 'tiktok';
    return value;
  }

  static String _normalizeActivityType(String? rawType) {
    final type = (rawType ?? '').toLowerCase().trim().replaceAll(' ', '_');
    switch (type) {
      case 'viewer_join':
      case 'user_join':
      case 'chat_join':
      case 'joined':
        return 'join';
      case 'new_follower':
      case 'new_follow':
        return 'follow';
      case 'new_subscriber':
      case 'new_sub':
        return 'subscribe';
      default:
        return type;
    }
  }

  static bool _isActivityType(String? rawType) {
    final type = _normalizeActivityType(rawType);
    if (type.isEmpty) return false;
    if (type == 'normal' ||
        type == 'message' ||
        type == 'chat' ||
        type == 'chat_message' ||
        type == 'chat:message' ||
        type == 'text' ||
        type == 'viewer_message') {
      return false;
    }
    return true;
  }

  /// True for any `activity:*` socket row except `activity:sync`, or for a non-chat `type`
  /// (`follow`, `join`, `raid`, …). Covers **`activity:event`** payloads whose kind is in
  /// `type` / `eventType` (normalized in [LiveStreamService._coalesceActivityType]) and typed
  /// channels like `activity:follow` / `activity:join`.
  static bool _isActivityPayload(Map<String, dynamic> payload) {
    final socketEvent = payload['socketEvent']?.toString().toLowerCase().trim();
    if (socketEvent != null &&
        socketEvent.startsWith('activity:') &&
        socketEvent != 'activity:sync') {
      return true;
    }
    return _isActivityType(payload['type']?.toString());
  }

  String _edgeGlowDedupeKeyForActivity(
      Map<String, dynamic> event, {
        required String platformKey,
      }) {
    final id = event['id']?.toString().trim();
    final metadata = event['metadata'];
    String messageId = '';
    if (metadata is Map) {
      messageId =
          (metadata['messageId'] ??
              metadata['message_id'] ??
              metadata['id'] ??
              '')
              .toString()
              .trim();
    }
    final type = _normalizeActivityType(event['type']?.toString());
    final ts =
    (event['timestamp'] ?? event['created_at'] ?? '').toString().trim();

    if (id != null && id.isNotEmpty) return '$platformKey|id:$id';
    if (messageId.isNotEmpty) return '$platformKey|mid:$messageId|$type';
    if (ts.isNotEmpty) return '$platformKey|$type|$ts';
    return '$platformKey|$type|${event.hashCode}';
  }

  bool _seenEdgeGlowRecently(String key) {
    final now = DateTime.now().toUtc();
    _edgeGlowEventSeenAt.removeWhere(
          (_, ts) => now.difference(ts) > const Duration(seconds: 12),
    );
    if (_edgeGlowEventSeenAt.containsKey(key)) return true;
    _edgeGlowEventSeenAt[key] = now;
    if (_edgeGlowEventSeenAt.length > 600) {
      final oldestKeys =
      _edgeGlowEventSeenAt.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      for (final entry in oldestKeys.take(100)) {
        _edgeGlowEventSeenAt.remove(entry.key);
      }
    }
    return false;
  }

  void _maybeTriggerEdgeGlowForActivity(Map<String, dynamic> event) {
    if (!_settings.notifications.value || !_settings.ledNotifications.value) {
      return;
    }
    if (!_isActivityPayload(event)) return;

    final currentUserId = _currentUserId();
    if (currentUserId.isNotEmpty && _activityUserId(event) == currentUserId) {
      return;
    }

    final selectedPlatform = _normalizePlatformKey(platform.value);
    final eventPlatform = _normalizePlatformKey(event['platform']?.toString());

    final glowPlatform =
    eventPlatform.isNotEmpty ? eventPlatform : selectedPlatform;
    if (glowPlatform.isEmpty) return;

    // Keep LED behavior aligned with chat visibility:
    // only for the currently visible stream platform, and only after that
    // platform webview/embed is fully ready in UI.
    if (glowPlatform != selectedPlatform) return;
    if (!isPlatformStreamEmbedReadyForChat(glowPlatform)) return;

    final dedupeKey = _edgeGlowDedupeKeyForActivity(
      event,
      platformKey: glowPlatform,
    );
    if (_seenEdgeGlowRecently(dedupeKey)) return;

    if (kDebugMode) {
      debugPrint(
        '[ACTIVITY_EVENT][EDGE_GLOW_TRIGGER] platform=$glowPlatform event=$event',
      );
    }
    _edgeGlow.triggerForPlatform(glowPlatform);
  }

  String _currentUserId() {
    try {
      final me = Get.find<AuthController>().me.value;
      if (me == null) return '';
      final raw =
          me['id'] ?? me['uid'] ?? me['userId'] ?? me['user_id'] ?? me['sub'];
      return raw?.toString().trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  String _activityUserId(Map<String, dynamic> event) {
    dynamic raw =
        event['userId'] ??
            event['user_id'] ??
            event['uid'] ??
            event['senderId'] ??
            event['sender_id'];

    final user = event['user'];
    if (raw == null && user is Map) {
      raw = user['id'] ?? user['uid'] ?? user['userId'] ?? user['user_id'];
    }

    final metadata = event['metadata'];
    if (raw == null && metadata is Map) {
      raw =
          metadata['userId'] ??
              metadata['user_id'] ??
              metadata['uid'] ??
              metadata['senderId'] ??
              metadata['sender_id'];
      final metaUser = metadata['user'];
      if (raw == null && metaUser is Map) {
        raw =
            metaUser['id'] ??
                metaUser['uid'] ??
                metaUser['userId'] ??
                metaUser['user_id'];
      }
    }

    return raw?.toString().trim() ?? '';
  }

  String _activityDedupeKey(Map<String, dynamic> event) {
    final id = event['id']?.toString().trim();
    if (id != null && id.isNotEmpty) return 'id:$id';

    final platform = _normalizePlatformKey(event['platform']?.toString());
    final type = _normalizeActivityType(
      (event['type'] ?? event['eventType'] ?? event['kind'])?.toString(),
    );
    final ts =
        (event['timestamp'] ?? event['created_at'] ?? '').toString().trim();
    final userId = _activityUserId(event);
    if (platform.isNotEmpty && type.isNotEmpty && ts.isNotEmpty) {
      return 'evt:$platform|$type|$ts|$userId';
    }

    final metadata = event['metadata'];
    var username = '';
    if (metadata is Map) {
      username =
          (metadata['username'] ??
                  metadata['user_name'] ??
                  metadata['user'] ??
                  '')
              .toString()
              .trim()
              .toLowerCase();
    }
    return 'fb:$platform|$type|$ts|$username|${event.hashCode}';
  }

  bool _rememberActivityDedupeKey(String key) {
    if (key.isEmpty) return false;
    if (_activityRealtimeDedupeKeys.contains(key)) return true;
    if (_activityRealtimeDedupeKeys.length > 2500) {
      _activityRealtimeDedupeKeys.clear();
    }
    _activityRealtimeDedupeKeys.add(key);
    return false;
  }

  /// Appends one realtime activity row from **`activity:event`** only.
  void _handleIncomingActivityEvent(Map<String, dynamic> event) {
    if (kDebugMode) {
      debugPrint('[ACTIVITY_EVENT][CHAT_CONTROLLER] $event');
    }
    if (!_isActivityPayload(event)) return;
    final normalized = Map<String, dynamic>.from(event);
    final type = _normalizeActivityType(
      (event['type'] ?? event['eventType'] ?? event['kind'])?.toString(),
    );
    if (type.isNotEmpty) normalized['type'] = type;

    final dedupeKey = _activityDedupeKey(normalized);
    if (_rememberActivityDedupeKey(dedupeKey)) return;

    activityEvents.add(normalized);
    _maybeTriggerEdgeGlowForActivity(normalized);
  }

  void _appendActivityFromChatMessage(
      ChatMessage msg, {
        bool triggerEdgeGlow = true,
      }) {
    final id = msg.id?.trim();
    final dedupe =
    id != null && id.isNotEmpty
        ? 'id:$id'
        : 'h:${msg.platform}|${msg.timestamp.toUtc().millisecondsSinceEpoch}|${msg.message.hashCode}|${_chatMessagePayloadType(msg)}';
    if (_activityChatSourceDedupeIds.contains(dedupe)) return;
    if (_activityChatSourceDedupeIds.length > 2500) {
      _activityChatSourceDedupeIds.clear();
    }
    _activityChatSourceDedupeIds.add(dedupe);

    final activityPayload = <String, dynamic>{
      'id': id,
      'platform': msg.platform,
      'type': _normalizeActivityType(_chatMessagePayloadType(msg)),
      'metadata': <String, dynamic>{
        'user': msg.userName,
        'username': msg.userName,
        'message': msg.message,
      },
      'timestamp': msg.timestamp.toUtc().toIso8601String(),
      'created_at': msg.timestamp.toUtc().toIso8601String(),
    };
    final activityDedupeKey = _activityDedupeKey(activityPayload);
    if (_rememberActivityDedupeKey(activityDedupeKey)) return;

    activityEvents.add(activityPayload);
    if (triggerEdgeGlow) {
      _maybeTriggerEdgeGlowForActivity(activityPayload);
    }
  }

  /// Realtime `chat:message` → `platformMessages` → `messages` when that platform is selected;
  /// `scrollTick` and `ever(messages)` drive auto-scroll in the live chat UI.
  void _handleIncomingChatMessage(ChatMessage msg) {
    if (!_isNormalChatMessage(msg)) {
      _appendActivityFromChatMessage(msg);
      return;
    }

    final p = _normalizePlatformKey(msg.platform);
    if (p.isEmpty) return;
    final routeKey = _normalizedApiPlatform(p, fallback: '');
    if (routeKey.isNotEmpty && platformLive[routeKey] == false) {
      return;
    }
    var normalizedMsg =
    msg.platform == p
        ? msg
        : ChatMessage(
      platform: p,
      userName: msg.userName,
      message: msg.message,
      timestamp: msg.timestamp,
      id: msg.id,
      raw: msg.raw,
    );
    _purgeStalePendingEchoes();

    final norm = msg.message.trim().toLowerCase();
    final pendingIdx = _pendingLocalChatEchoes.indexWhere(
          (e) => e.platform == p && e.normalizedText == norm,
    );

    if (pendingIdx != -1) {
      final echo = _pendingLocalChatEchoes.removeAt(pendingIdx);
      var list = List<ChatMessage>.from(platformMessages[p] ?? []);
      list.removeWhere((m) => m.id == echo.localMessageId);
      list.add(normalizedMsg);
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      list = _collapseNearDuplicates(list);
      platformMessages[p] = list;
      platformMessages.refresh();
      _syncVisibleMessagesIfSelected(p);
      _bumpScroll();
      return;
    }

    final existing = List<ChatMessage>.from(platformMessages[p] ?? []);
    final incomingCanonical = _canonicalIdForPlatform(normalizedMsg);
    if (incomingCanonical != null && incomingCanonical.isNotEmpty) {
      final alreadyIdx = existing.indexWhere(
        (m) => _canonicalIdForPlatform(m) == incomingCanonical,
      );
      if (alreadyIdx != -1) {
        final replaced = List<ChatMessage>.from(existing);
        replaced[alreadyIdx] = normalizedMsg;
        replaced.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        platformMessages[p] = _collapseNearDuplicates(replaced);
        platformMessages.refresh();
        _syncVisibleMessagesIfSelected(p);
        _bumpScroll();
        return;
      }
    }

    // Kick provider can occasionally echo the same current-user line with a
    // slightly different payload shape; upsert instead of appending.
    if (p == 'kick' && _isLikelyCurrentUserMessage(normalizedMsg)) {
      final replaceIdx = _findUpsertIndexForSameSenderAndText(
        existing,
        normalizedMsg,
      );
      if (replaceIdx != -1) {
        final replaced = List<ChatMessage>.from(existing);
        replaced[replaceIdx] = normalizedMsg;
        replaced.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        platformMessages[p] = _collapseNearDuplicates(replaced);
        platformMessages.refresh();
        _syncVisibleMessagesIfSelected(p);
        _bumpScroll();
        return;
      }
    }

    if (_shouldSuppressSocketNearDuplicate(existing, normalizedMsg)) {
      return;
    }

    final merged = _mergeUniqueByDedupeKey(existing, <ChatMessage>[
      normalizedMsg,
    ]);
    merged.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    platformMessages[p] = _collapseNearDuplicates(merged);
    platformMessages.refresh();
    _syncVisibleMessagesIfSelected(p);
    _bumpScroll();
  }

  Future<void> _swapToPlatformAndRefresh(
      String p, {
        bool forceHistory = false,
        bool fetchHistory = true,
      }) async {
    final key = _normalizePlatformKey(p);
    if (key.isEmpty) return;

    // 0) Instant player/chat switch: never keep previous platform stream visible.
    final cachedLive = platformLive[key];
    if (cachedLive == false) {
      isLive.value = false;
      viewerCount.value = platformViewerCounts[key] ?? 0;
      watchUrl.value = '';
      platformMessages[key] = const <ChatMessage>[];
      if (platform.value.toLowerCase().trim() == key) {
        messages.clear();
      }
      _bumpScroll();
    } else if (cachedLive == true) {
      isLive.value = true;
      viewerCount.value = platformViewerCounts[key] ?? 0;
      final u = platformEmbedUrls[key];
      watchUrl.value = (u != null && u.trim().isNotEmpty) ? u : '';
    } else {
      // Unknown state: avoid showing old stream while we fetch.
      viewerCount.value = platformViewerCounts[key] ?? 0;
      watchUrl.value = '';
    }

    // 1) Swap visible list instantly.
    final existing = platformMessages[key] ?? const <ChatMessage>[];
    if (messages.isEmpty || !identical(messages, existing)) {
      messages.assignAll(existing);
      _bumpScroll();
    }

    if (!fetchHistory) return;

    // 2) Fetch latest history for that platform (fast + safe).
    await _refreshHistoryForPlatform(key, force: forceHistory);
  }

  static DateTime _activityEventTimeUtc(Map<String, dynamic> e) {
    final t = e['timestamp'] ?? e['created_at'] ?? e['createdAt'];
    if (t == null) return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    if (t is DateTime) return t.toUtc();
    if (t is int) {
      return t > 1000000000000
          ? DateTime.fromMillisecondsSinceEpoch(t, isUtc: true)
          : DateTime.fromMillisecondsSinceEpoch(t * 1000, isUtc: true);
    }
    return DateTime.tryParse(t.toString())?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  /// Merges `activities` from GET `/chat/history` into [activityEvents] (deduped by `id`).
  void _mergeHistoryActivitiesFromApi(
      List<Map<String, dynamic>> raw, {
        required String platformKey,
      }) {
    if (raw.isEmpty) return;

    // UI renders `activityEvents.reversed` (newest-first on screen),
    // so keep storage canonical as oldest -> newest.
    var normalizedRaw = List<Map<String, dynamic>>.from(raw);
    bool shouldReverse = true; // API history is typically newest -> oldest.
    if (normalizedRaw.length >= 2) {
      final firstTs = _activityEventTimeUtc(normalizedRaw.first);
      final lastTs = _activityEventTimeUtc(normalizedRaw.last);
      final firstValid =
          firstTs.millisecondsSinceEpoch >
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
              .millisecondsSinceEpoch;
      final lastValid =
          lastTs.millisecondsSinceEpoch >
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
              .millisecondsSinceEpoch;
      if (firstValid && lastValid) {
        // If first is older than last, data is already oldest -> newest.
        shouldReverse = firstTs.isAfter(lastTs);
      }
    }
    if (shouldReverse) {
      normalizedRaw = normalizedRaw.reversed.toList(growable: false);
    }

    final existingIds = <String>{
      for (final e in activityEvents)
        if (e['id'] != null) e['id'].toString().trim(),
    }..removeWhere((s) => s.isEmpty);

    final toAdd = <Map<String, dynamic>>[];
    for (final item in normalizedRaw) {
      if (!_isActivityPayload(item)) continue;

      final eventPlatform = _normalizePlatformKey(item['platform']?.toString());
      if (eventPlatform.isNotEmpty && eventPlatform != platformKey) continue;

      final id = item['id']?.toString().trim() ?? '';
      if (id.isNotEmpty && existingIds.contains(id)) continue;

      final copy = Map<String, dynamic>.from(item);
      final normalizedType = _normalizeActivityType(
        (copy['type'] ?? copy['eventType'] ?? copy['kind'])?.toString(),
      );
      if (normalizedType.isNotEmpty) copy['type'] = normalizedType;
      final meta = copy['metadata'];
      if (meta is Map) {
        final mm = Map<String, dynamic>.from(meta.cast<String, dynamic>());
        final login =
        (mm['user_login'] ??
            mm['user_name'] ??
            mm['username'] ??
            mm['user'])
            ?.toString()
            .trim();
        if (login != null && login.isNotEmpty) {
          mm.putIfAbsent('user', () => login);
          mm.putIfAbsent('username', () => login);
        }
        copy['metadata'] = mm;
      }

      if (id.isNotEmpty) existingIds.add(id);
      _rememberActivityDedupeKey(_activityDedupeKey(copy));
      toAdd.add(copy);
    }

    if (toAdd.isEmpty) return;
    for (final m in toAdd) {
      activityEvents.add(m);
    }
    activityEvents.refresh();
  }

  Future<void> _refreshHistoryForPlatform(
      String platformKey, {
        bool force = false,
      }) {
    final key = _normalizedApiPlatform(platformKey, fallback: 'twitch');
    if (key.isEmpty) return Future.value();

    final pending = _historyRefreshCoalesce[key];
    if (pending != null) return pending;

    final run = _refreshHistoryForPlatformImpl(key, force: force);
    _historyRefreshCoalesce[key] = run;
    run.whenComplete(() {
      if (_historyRefreshCoalesce[key] == run) {
        _historyRefreshCoalesce.remove(key);
      }
    });
    return run;
  }

  Future<void> _refreshHistoryForPlatformImpl(
      String key, {
        bool force = false,
      }) async {
    final now = DateTime.now().toUtc();
    final last = _historyLastFetchAt[key];
    if (!force &&
        last != null &&
        now.difference(last) < _historyMinRefreshInterval) {
      return;
    }

    final token = await _resolveChatAuthToken(key);
    if (token == null || token.trim().isEmpty) return;

    try {
      final historyResult = await _live.loadHistory(
        platform: key,
        accessToken: token,
        limit: 100,
        offset: 0,
        onLogLine: _appendSocketInboundLog,
      );

      _mergeHistoryActivitiesFromApi(
        historyResult.activities,
        platformKey: key,
      );

      final history = historyResult.messages;
      if (history.isNotEmpty) {
        final normalOnly = <ChatMessage>[];
        for (final m in history) {
          if (_isNormalChatMessage(m)) {
            normalOnly.add(m);
          } else {
            _appendActivityFromChatMessage(m, triggerEdgeGlow: false);
          }
        }
        final merged = _mergeUniqueByDedupeKey(
          platformMessages[key] ?? const <ChatMessage>[],
          normalOnly,
        );
        merged.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        final collapsed = _collapseNearDuplicates(merged);
        platformMessages[key] = collapsed;
        if (platform.value.toLowerCase() == key) {
          messages.assignAll(collapsed);
        }
        platformMessages.refresh();
        _bumpScroll();
      }
      _historyLastFetchAt[key] = now;
    } catch (_) {
      // silent
    }
  }

  List<ChatMessage> _mergeUniqueByDedupeKey(
      List<ChatMessage> a,
      List<ChatMessage> b,
      ) {
    final out = <ChatMessage>[];
    final seen = <String>{};
    final seenCanonicalIds = <String>{};
    void addAll(List<ChatMessage> list) {
      for (final m in list) {
        final canonicalId = _canonicalIdForPlatform(m);
        if (canonicalId != null && canonicalId.isNotEmpty) {
          if (!seenCanonicalIds.add(canonicalId)) {
            continue;
          }
        }
        final k = m.dedupeKey;
        if (seen.add(k)) out.add(m);
      }
    }

    // Prefer keeping existing realtime ordering, then add any missing from history.
    addAll(a);
    addAll(b);
    return out;
  }

  Future<void> _ensureChatForLivePlatform(
      String p, {
        bool forceHistory = false,
      }) async {
    final key = p.toLowerCase();
    // 1) Socket ensure connect (no-op if already connected)
    if (isConnected.value != true) {
      await _tryConnectIfPossible();
    }

    // 2) History refresh (per-platform list)
    await _refreshHistoryForPlatform(key, force: forceHistory);
  }

  void _bumpScroll() {
    // Cheap observable tick for UI that can't easily diff RxList changes.
    scrollTick.value++;
  }

  static int? _parseSocketStreakCount(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw == null) return null;
    return int.tryParse(raw.toString().trim());
  }

  void _applySocketStreakCount(int count) {
    if (!Get.isRegistered<StreamStreaksController>()) return;
    final normalized = count < 0 ? 0 : count;
    Get.find<StreamStreaksController>().applySocketStreakCount(normalized);
    if (kDebugMode) {
      debugPrint('[ChatController] stream:status streak_count=$normalized');
    }
  }

  void _handlePlatformSwitchRequest(String key) {
    final normalized = _normalizedApiPlatform(key, fallback: 'twitch');
    if (normalized.isEmpty) return;
    // Platform switching is cache-only: chat filtering + platform data swap.
    unawaited(_swapToPlatformAndRefresh(normalized, fetchHistory: false));
  }

  /// Disconnect realtime chat and clear lists after full logout.
  Future<void> resetForLogout() async {
    _overviewRefreshCoalesce.clear();
    _historyRefreshCoalesce.clear();
    _connectRetryTimer?.cancel();
    _connectRetryTimer = null;
    _pendingLocalChatEchoes.clear();
    _historyLastFetchAt.clear();
    _activityChatSourceDedupeIds.clear();
    _activityRealtimeDedupeKeys.clear();
    _edgeGlowEventSeenAt.clear();
    for (final t in _pendingOfflineTimers.values) {
      t.cancel();
    }
    _pendingOfflineTimers.clear();
    _pendingOfflineVotes.clear();
    _lastConfirmedLiveAt.clear();
    _lastPlayerUrlUpdateAt.clear();
    _realtimeObserversWired = false;
    if (Get.isRegistered<StreamStreaksController>()) {
      Get.find<StreamStreaksController>().clearSocketStreakCount();
    }
    try {
      await _live.disconnect();
    } catch (_) {}
    _socketAuthToken = null;
    _socketBaseUrl = null;
    _socketPath = null;
    platformMessages.clear();
    messages.clear();
    activityEvents.clear();
    platformViewerCounts.clear();
    platformLive.clear();
    platformEmbedUrls.clear();
    platformChatUsernames.clear();
    platformLastStopReason.clear();
    streamTitleByPlatform.clear();
    streamCategoryByPlatform.clear();
    _oauthUserDisconnectedPlatforms.clear();
    overview.value = null;
    watchUrl.value = null;
    isLive.value = false;
    viewerCount.value = 0;
    isConnected.value = false;
    scrollTick.value = 0;
    socketInboundLog.clear();
    _startConnectRetry();
  }

  void _wireServiceCallbacks() {
    _live.onSocketInbound = _appendSocketInboundLog;
    _live.onSocketConnected = () {
      isConnected.value = true;
      _mirrorCurrentPlatformSnapshot(event: 'socket:connect');
      final selected = _normalizedApiPlatform(
        platform.value,
        fallback: 'twitch',
      );
      if (selected.isNotEmpty &&
          platformStreamEmbedReady[selected] == true) {
        unawaited(_refreshHistoryForPlatform(selected, force: false));
      }
    };
    _live.onSocketDisconnected = (_) {
      isConnected.value = false;
      _mirrorCurrentPlatformSnapshot(event: 'socket:disconnect');
    };
    _live.onSocketError = (m) async {
      final msg = (m['message'] ?? '').toString();
      if (msg.contains('Invalid authentication token') ||
          msg.contains('Authentication token required')) {
        final selected = platform.value.toLowerCase();
        final fresh = await _resolveChatAuthToken(selected);
        if (fresh != null && fresh.trim().isNotEmpty) {
          _socketAuthToken = fresh.trim();
          await refreshOverviewForPlatform(selected);
          unawaited(_tryConnectIfPossible());
        }
        return;
      }

      // Keep the socket resilient for transient provider/network failures.
      final lower = msg.toLowerCase();
      final isReconnectWorthy =
          lower.contains('timeout') ||
          lower.contains('timed out') ||
          lower.contains('transport') ||
          lower.contains('closed') ||
          lower.contains('disconnect') ||
          lower.contains('network') ||
          lower.contains('connect_error');
      if (isReconnectWorthy) {
        _lastSocketConnectAttempt = DateTime.fromMillisecondsSinceEpoch(0);
        unawaited(_tryConnectIfPossible());
      }
    };
    // Professional handling: mutate state only from `stream:status` socket snapshots.
    _live.onViewerCountUpdate = (_, __) {};
    _live.onLiveUpdate = (_, __) {};
    _live.onPlayerUrlUpdate = (_, __) {};
    _live.onActivityEvent = (e) {
      _handleIncomingActivityEvent(e);
    };
    _live.onLedNotification = (payload) {
      final event = <String, dynamic>{...payload};
      event['platform'] = (event['platform'] ?? platform.value).toString();
      event['type'] =
          (event['type'] ??
              event['eventType'] ??
              event['kind'] ??
              event['event'] ??
              'notification')
              .toString();
      _maybeTriggerEdgeGlowForActivity(event);
    };
    void applyStreamStatus(Map<String, dynamic> m) {
      final p = _normalizedApiPlatform((m['platform'] ?? '').toString());
      if (p.isEmpty) return;

      final liveRaw = m['live'];
      if (liveRaw is bool &&
          liveRaw &&
          _oauthUserDisconnectedPlatforms.contains(p)) {
        _setPlatformLiveStable(
          p,
          false,
          source: 'socket:stream_status_blocked_oauth_disconnect',
          forceOffline: true,
        );
        return;
      }
      if (liveRaw is bool) {
        // Authoritative socket snapshot: offline is immediate (no vote/hold debounce).
        // Stale `player` URLs in the same payload must not resurrect the embed (see below).
        _setPlatformLiveStable(
          p,
          liveRaw,
          source: 'socket:stream_status',
          forceOffline: !liveRaw,
        );
      }

      final vcAny = m['viewerCount'] ?? m['viewer_count'] ?? m['viewers'];
      int? vc;
      if (vcAny is int) {
        vc = vcAny;
      } else if (vcAny is num) {
        vc = vcAny.toInt();
      } else if (vcAny != null) {
        vc = int.tryParse(vcAny.toString().trim());
      }
      if (vc != null) {
        if (_setViewerCountIfChanged(p, vc)) {
          platformViewerCounts.refresh();
        }
      }

      String? preferredUrl;
      final playerAny = m['player'];
      if (playerAny is Map) {
        final player = playerAny.cast<String, dynamic>();
        final embedUrl =
        (player['embedUrl'] ?? player['embed_url'])?.toString().trim();
        final watch =
        (player['watchUrl'] ?? player['watch_url'] ?? player['url'])
            ?.toString()
            .trim();
        if (embedUrl != null && embedUrl.isNotEmpty) {
          preferredUrl = embedUrl;
        } else if (watch != null && watch.isNotEmpty) {
          preferredUrl = watch;
        }
      }
      // Only attach player URLs while that platform is live — payloads often still
      // include embed/watch URLs after `live: false`, which would keep WebView/chat warm.
      if (platformLive[p] == true &&
          preferredUrl != null &&
          preferredUrl.isNotEmpty) {
        final effectivePreferredUrl =
            p == 'twitch'
                ? _withStreamReloadMarker(preferredUrl)
                : preferredUrl;
        _lastPlayerUrlUpdateAt[p] = DateTime.now().toUtc();
        if (_setEmbedUrlIfChanged(p, effectivePreferredUrl)) {
          platformEmbedUrls.refresh();
        }
        // Do not force `/chat/history` from socket status ticks.
        // History is loaded by [onPlatformStreamWebViewReady] for each live session.
      }

      _applyStreamTitleCategory(p, m);

      if (m.containsKey('streak_count') || m.containsKey('streakCount')) {
        final streakRaw = m['streak_count'] ?? m['streakCount'];
        final streakCount = _parseSocketStreakCount(streakRaw);
        if (streakCount != null) {
          _applySocketStreakCount(streakCount);
        }
      }

      final selected = _normalizedApiPlatform(
        platform.value,
        fallback: 'twitch',
      );
      if (selected == p) {
        isLive.value = platformLive[p] == true;
        viewerCount.value = platformViewerCounts[p] ?? viewerCount.value;
        final selectedUrl = platformEmbedUrls[p];
        if (isLive.value == true) {
          watchUrl.value =
          (selectedUrl != null && selectedUrl.trim().isNotEmpty)
              ? selectedUrl
              : watchUrl.value;
        } else {
          watchUrl.value = '';
        }
      }

      _firebaseMirror.updatePlatformSnapshot(
        platform: p,
        live: platformLive[p] == true,
        viewerCount: platformViewerCounts[p],
        title: streamTitleByPlatform[p] ?? '',
        category: streamCategoryByPlatform[p] ?? '',
        socketConnectedInApp: isConnected.value,
        accountConnected: _isAccountConnected(p),
        latestEvent: 'stream:status',
      );
      _logStreamSnapshot('socket:stream_status');
    }

    _live.onStreamStatus = applyStreamStatus;
    _live.onStreamInfoUpdate = applyStreamStatus;
    _live.onChatMessage = _handleIncomingChatMessage;
  }

  /// Public: always fetch latest chat history from server (no UI caching).
  /// Socket messages are still appended in realtime, but this ensures you don't
  /// miss messages after reconnect or backgrounding.
  Future<void> refreshChatHistory({String? forPlatform, bool force = true}) {
    final key = _normalizedApiPlatform(
      forPlatform ?? platform.value,
      fallback: 'twitch',
    );
    return _refreshHistoryForPlatform(key, force: force);
  }

  /// Switch selected platform immediately using cached state only.
  void selectPlatformInstant(String p) {
    try {
      final key = _normalizedApiPlatform(p, fallback: 'twitch');
      if (key.isEmpty) return;

      final cachedLive = platformLive[key];
      final cachedUrl = platformEmbedUrls[key];
      if (cachedLive == true) {
        isLive.value = true;
        watchUrl.value =
        (cachedUrl != null && cachedUrl.trim().isNotEmpty) ? cachedUrl : '';
      } else if (cachedLive == false) {
        isLive.value = false;
        watchUrl.value = '';
      } else {
        isLive.value = false;
        watchUrl.value =
        (cachedUrl != null && cachedUrl.trim().isNotEmpty) ? cachedUrl : '';
      }

      messages.assignAll(platformMessages[key] ?? const <ChatMessage>[]);
      _bumpScroll();

      if (platform.value.toLowerCase().trim() != key) {
        platform.value = key;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ChatController] selectPlatformInstant failed: $e');
      }
    }
  }

  bool _isAccountConnected(String platformKey) {
    final key = _normalizedApiPlatform(platformKey, fallback: '');
    if (key.isEmpty) return false;
    return platformChatUsernames[key]?.trim().isNotEmpty == true;
  }

  void _mirrorCurrentPlatformSnapshot({required String event}) {
    // Firebase mirror updates are intentionally limited to socket `stream:status`.
    // This method is kept as no-op to avoid writing mirror docs from any other path.
    return;
  }

  /// Called when OAuth connect succeeds for a platform.
  /// Refreshes only that platform overview once and reconnects socket if needed.
  Future<void> onPlatformConnectedSuccessfully(String platformKey) async {
    final key = _normalizedApiPlatform(platformKey, fallback: '');
    if (key.isEmpty) return;
    _oauthUserDisconnectedPlatforms.remove(key);

    // Reconnect while stream is already live should behave like a fresh live
    // session for chat/activity bootstrap: wait for next full WebView ready
    // callback, then fetch history+activities again.
    _clearHistoryTriggerForPlatform(key);
    _liveSessionSeqByPlatform[key] = (_liveSessionSeqByPlatform[key] ?? 0) + 1;
    if (platformLive[key] == true) {
      platformStreamEmbedReady[key] = false;
      platformStreamEmbedReady.refresh();
    }

    await refreshOverviewForPlatform(key, forceChatHistory: true);
    // Server chat routing is tied to `chat:start` after the linked-account set changes.
    // If the socket stayed up across OAuth disconnect/reconnect, [_tryConnectIfPossible]
    // would no-op while `isConnected` is true and `chat:message` can stop for that platform
    // while other events (e.g. activity) still arrive — force a full reconnect.
    if (isConnected.value) {
      _lastSocketConnectAttempt = DateTime.fromMillisecondsSinceEpoch(0);
      try {
        await _live.disconnect();
      } catch (_) {}
    }
    await _tryConnectIfPossible();
  }

  Future<bool> updateStreamMetadata({
    required String platformKey,
    required String title,
    required String category,
    String? categoryId,
  }) async {
    final p = _normalizedApiPlatform(platformKey, fallback: '');
    if (p.isEmpty) return false;
    final nextTitle = title.trim();
    final nextCategory = category.trim();
    if (nextTitle.isEmpty) return false;

    try {
      final auth = Get.find<AuthController>();
      await auth.ensureValidSession(refreshIfExpired: true);

      final payload = <String, dynamic>{'title': nextTitle};
      if (nextCategory.isNotEmpty) {
        payload['category'] = nextCategory;
        final normalizedCategoryId = categoryId?.trim();
        if (normalizedCategoryId != null && normalizedCategoryId.isNotEmpty) {
          payload['categoryId'] = normalizedCategoryId;
        }
      }

      // Same client as `/api/v1/settings`, `/api/v1/platforms`, etc.: [AuthInterceptor]
      // attaches the backend session JWT — do not override with Google/platform tokens.
      await auth.api.client.dio.patch<dynamic>(
        '/api/v1/platforms/$p/stream',
        data: payload,
      );

      streamTitleByPlatform[p] = nextTitle;
      streamCategoryByPlatform[p] = nextCategory;
      streamTitleByPlatform.refresh();
      streamCategoryByPlatform.refresh();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void onClose() {
    _connectRetryTimer?.cancel();
    _connectRetryTimer = null;
    _pendingLocalChatEchoes.clear();
    _historyRefreshCoalesce.clear();
    _historyLastFetchAt.clear();
    _edgeGlowEventSeenAt.clear();
    for (final t in _pendingOfflineTimers.values) {
      t.cancel();
    }
    _pendingOfflineTimers.clear();
    _pendingOfflineVotes.clear();
    _lastConfirmedLiveAt.clear();
    _lastPlayerUrlUpdateAt.clear();
    try {
      _live.disconnect();
    } catch (_) {}
    super.onClose();
  }
}

class _PendingLocalChatEcho {
  _PendingLocalChatEcho({
    required this.platform,
    required this.normalizedText,
    required this.localMessageId,
    required this.createdAt,
  });
  final String platform;
  final String normalizedText;
  final String localMessageId;
  final DateTime createdAt;
}
