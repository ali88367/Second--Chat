import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'auth_controller.dart';
import 'edge_glow_notification_controller.dart';
import '../controllers/Main Section Controllers/settings_controller.dart';
import '../core/utils/platform_token_provider.dart';
import '../data/models/chat_message.dart';
import '../data/models/streaming_overview.dart';
import '../data/services/live_stream_service.dart';

class ChatController extends GetxController {
  ChatController({
    PlatformTokenProvider? tokenProvider,
    LiveStreamService? liveStreamService,
  }) : _tokenProvider = tokenProvider ?? PlatformTokenProvider(),
       _live =
           liveStreamService ??
           LiveStreamService(tokenProvider: tokenProvider ?? PlatformTokenProvider());

  final PlatformTokenProvider _tokenProvider;
  final SettingsController _settings = Get.find<SettingsController>();
  final EdgeGlowNotificationController _edgeGlow =
      Get.find<EdgeGlowNotificationController>();
  final LiveStreamService _live;

  final RxString platform = 'twitch'.obs;

  final RxnString watchUrl = RxnString();
  final RxBool isLive = false.obs;
  final Rxn<StreamingOverview> overview = Rxn<StreamingOverview>();
  final RxMap<String, int> platformViewerCounts = <String, int>{}.obs;
  final RxMap<String, bool> platformLive = <String, bool>{}.obs;
  final RxMap<String, String?> platformEmbedUrls = <String, String?>{}.obs;
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
  DateTime _lastPlatformSocketSwitchAttempt = DateTime.fromMillisecondsSinceEpoch(0);
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
  final Map<String, DateTime> _edgeGlowEventSeenAt = <String, DateTime>{};

  /// Own messages: show immediately, then replace with the socket echo (same text).
  final List<_PendingLocalChatEcho> _pendingLocalChatEchoes = [];

  final RxList<ChatMessage> messages = <ChatMessage>[].obs;
  final RxInt viewerCount = 0.obs;
  final RxBool isConnected = false.obs;

  final RxInt scrollTick = 0.obs; // UI can observe this to auto-scroll.

  /// Auth for Socket.IO + `/api/v1/chat/*`: **backend** bearer (session JWT or platform token), never Google `ya29…`.
  String? _socketAuthToken;
  String? _socketBaseUrl;
  String? _socketPath;
  String? _socketConnectedPlatform;
  String? _socketConnectedToken;

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
  }

  /// Backend session JWT + platform tokens for **`GET /streaming/overview`** only
  /// (Second Chat REST; keep JWT-first so socket URL loads reliably).
  Future<String?> _resolveStreamingRestToken(String platformKey) async {
    try {
      final session = await Get.find<AuthController>().api.tokenStore.read();
      final appJwt = session?.accessToken.trim();
      if (appJwt != null && appJwt.isNotEmpty) return appJwt;
    } catch (_) {}
    final p = platformKey.toLowerCase().trim();
    if (p.isEmpty) return null;
    return await _live.ensureFreshPlatformAccessToken(platform: p) ??
        await _tokenProvider.getAccessToken(p);
  }

  /// **`/api/v1/chat/*`** and Socket.IO (§5): backend **`accessToken` (JWT)** per `API_SOCKET_DETAILS.md`.
  ///
  /// Google’s OAuth **access** token (`ya29…`) is for Google APIs only — the Second Chat server
  /// validates **its own** JWT (from `/auth/login`, `/auth/google/token` with `idToken`, etc.).
  /// Using the Google access token here causes `Invalid authentication token` on the socket.
  Future<String?> _resolveChatAuthToken(String platformKey) async {
    return _resolveStreamingRestToken(platformKey);
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
    _wireServiceCallbacks();
    _scheduleBootstrapAfterAuth();
    ever<String>(platform, (p) {
      final key = _normalizedApiPlatform(p, fallback: 'twitch');
      // Instant UI from cache; do not fetch history here — [refreshOverviewForPlatform] does once.
      unawaited(_swapToPlatformAndRefresh(key, fetchHistory: false));
      unawaited(refreshOverviewForPlatform(key));
    });

    // If tokens/overview are not ready at first app launch, connect may skip.
    // Retry in background so socket starts without needing page navigation.
    _startConnectRetry();

    // Keep multi-preview links "hot" when user toggles the setting.
    ever<bool>(_settings.multiScreenPreview, (enabled) {
      if (enabled == true) {
        unawaited(
          refreshOverviewsForPlatforms(const ['twitch', 'kick', 'youtube']),
        );
      }
    });
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
      if (now.difference(_lastSocketConnectAttempt) < const Duration(seconds: 3)) {
        return;
      }
      _lastSocketConnectAttempt = now;

      final selected = _normalizedApiPlatform(platform.value, fallback: 'twitch');
      final token = await _resolveChatAuthToken(selected);
      if (token == null || token.trim().isEmpty) return;
      _socketAuthToken = token.trim();

      // Ensure we have socketUrl/socketPath in `overview`.
      var socketUrl = _socketBaseUrl;
      var socketPath = _socketPath;

      final hasSocketFields = socketUrl != null &&
          socketUrl.trim().isNotEmpty &&
          socketPath != null &&
          socketPath.trim().isNotEmpty;

      if (!hasSocketFields) {
        // Refresh only the selected platform overview; it also updates socketUrl/path.
        await refreshOverviewForPlatform(selected);
        socketUrl = _socketBaseUrl;
        socketPath = _socketPath;
      }

      if (socketUrl == null ||
          socketUrl.trim().isEmpty ||
          socketPath == null ||
          socketPath.trim().isEmpty) {
        return;
      }

      if (isConnected.value == true &&
          _socketConnectedPlatform == selected &&
          _socketConnectedToken == _socketAuthToken) {
        return;
      }

      await _live.connect(
        baseUrl: socketUrl.trim(),
        path: socketPath.trim(),
        accessToken: _socketAuthToken!,
        label: selected,
      );
      _socketConnectedPlatform = selected;
      _socketConnectedToken = _socketAuthToken;

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
      var selected = _normalizedApiPlatform(platform.value, fallback: 'twitch');
      // 1) App start: hit overview for each connected platform (tokens in SharedPrefs).
      final connectedPlatforms = await _tokenProvider.getConnectedPlatforms();
      if (connectedPlatforms.isNotEmpty) {
        // Keep default selection as-is unless it's not connected.
        if (!connectedPlatforms.contains(selected)) {
          platform.value = connectedPlatforms.first;
          selected = _normalizedApiPlatform(platform.value, fallback: 'twitch');
        }
        await refreshOverviewsForPlatforms(connectedPlatforms);
      }

      // Socket + chat: Google OAuth access token when signed in with Google, else session JWT.
      _socketAuthToken = await _resolveChatAuthToken(selected);
      if (_socketAuthToken == null || _socketAuthToken!.isEmpty) return;

      await _swapToPlatformAndRefresh(selected, forceHistory: true);

      // Ensure we have socketUrl/path even if connectedPlatforms was empty.
      if (overview.value == null) {
        await refreshOverviewForPlatform(selected);
      }

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
        _socketConnectedPlatform = selected;
        _socketConnectedToken = _socketAuthToken;
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

      if (mergedViewer.isNotEmpty) platformViewerCounts.assignAll(mergedViewer);
      if (mergedLive.isNotEmpty) platformLive.assignAll(mergedLive);
      if (mergedEmbed.isNotEmpty) platformEmbedUrls.assignAll(mergedEmbed);
      if (mergedUsernames.isNotEmpty) {
        for (final e in mergedUsernames.entries) {
          final v = e.value?.trim() ?? '';
          if (v.isNotEmpty) platformChatUsernames[e.key] = v;
        }
        platformChatUsernames.refresh();
      }

      // Update currently selected stream URL.
      final currentUrl = mergedEmbed[current] ?? primary.watchUrl;
      watchUrl.value = currentUrl;
      isLive.value = mergedLive[current] ?? primary.live;
      _logStreamSnapshot('rest:overview_multi');
    } catch (_) {}
  }

  String _maskToken(String? token) {
    final t = token?.trim() ?? '';
    if (t.isEmpty) return '(empty)';
    if (t.length <= 10) return '(${t.length} chars)';
    return '${t.substring(0, 6)}...${t.substring(t.length - 4)} (${t.length} chars)';
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
      final hasAny = live != null ||
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
    final run = _refreshOverviewForPlatformBody(key, forceChatHistory: forceChatHistory);
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
      // Do not overwrite [_socketAuthToken]: overview uses app/platform JWT; socket uses [_resolveChatAuthToken].

      // If multi-preview mode is enabled, refresh all platforms so the top streams stay "hot".
      if (_settings.multiScreenPreview.value == true) {
        if (kDebugMode) {
          debugPrint('[ChatController] multiScreenPreview=ON; refreshing all');
        }
        await refreshOverviewsForPlatforms(const ['twitch', 'kick', 'youtube']);
        // selected platform state still needs to update.
        if (platform.value.toLowerCase().trim() != p.toLowerCase().trim()) {
          platform.value = p;
        }
        unawaited(_switchSocketToPlatform(p));
        final key = p.toLowerCase();
        isLive.value = platformLive[key] ?? isLive.value;
        watchUrl.value = platformEmbedUrls[key] ?? watchUrl.value;
        if (isLive.value == true) {
          unawaited(_ensureChatForLivePlatform(key, forceHistory: forceChatHistory));
        } else {
          platformMessages[key] = const <ChatMessage>[];
          if (platform.value.toLowerCase().trim() == key) {
            messages.clear();
            _bumpScroll();
          }
        }
        _logStreamSnapshot('rest:overview_platform_multi_preview');
        return;
      }

      final ov = await _live.fetchOverview(
        platform: p,
        accessToken: token,
      );
      if (ov == null) return;
      overview.value = ov;
      for (final e in ov.usernamesByPlatform.entries) {
        final v = e.value?.trim() ?? '';
        if (v.isNotEmpty) platformChatUsernames[e.key] = v;
      }
      platformChatUsernames.refresh();
      _socketBaseUrl = ov.chatSocketUrl ?? _socketBaseUrl;
      _socketPath = ov.chatSocketPath ?? _socketPath;
      // selected platform state
      if (platform.value.toLowerCase().trim() != p.toLowerCase().trim()) {
        platform.value = p;
      }
      unawaited(_switchSocketToPlatform(p));
      isLive.value = ov.live;
      watchUrl.value = ov.watchUrl;
      // multi-platform state
      if (ov.viewerCountsByPlatform.isNotEmpty) {
        platformViewerCounts.assignAll(ov.viewerCountsByPlatform);
      }
      if (ov.liveByPlatform.isNotEmpty) {
        platformLive.assignAll(ov.liveByPlatform);
      } else {
        platformLive[p.toLowerCase()] = ov.live;
      }
      if (ov.embedUrlByPlatform.isNotEmpty) {
        platformEmbedUrls.assignAll(ov.embedUrlByPlatform);
      } else {
        platformEmbedUrls[p.toLowerCase()] = ov.watchUrl;
      }
      if (ov.live == true) {
        unawaited(
          _ensureChatForLivePlatform(p.toLowerCase(), forceHistory: forceChatHistory),
        );
      } else {
        final key = p.toLowerCase().trim();
        platformMessages[key] = const <ChatMessage>[];
        if (platform.value.toLowerCase().trim() == key) {
          messages.clear();
          _bumpScroll();
        }
      }
      _logStreamSnapshot('rest:overview_platform');
    } catch (_) {}
  }

  Future<void> _switchSocketToPlatform(String p) async {
    final key = p.toLowerCase().trim();
    if (key.isEmpty) return;
    // Debounce platform socket switching (chip tap + swipe can fire quickly).
    final now = DateTime.now();
    if (now.difference(_lastPlatformSocketSwitchAttempt) <
        const Duration(milliseconds: 120)) {
      return;
    }
    _lastPlatformSocketSwitchAttempt = now;

    final token = await _resolveChatAuthToken(key);
    if (token == null || token.trim().isEmpty) return;
    _socketAuthToken = token.trim();
    if (isConnected.value == true &&
        _socketConnectedPlatform == key &&
        _socketConnectedToken == _socketAuthToken) {
      return;
    }

    // Ensure socket url/path is available (from last overview fetch).
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
      label: key,
    );
    _socketConnectedPlatform = key;
    _socketConnectedToken = _socketAuthToken;
  }

  bool isPlatformLive(String p) {
    final key = _normalizedApiPlatform(p);
    if (key.isEmpty) return false;
    return platformLive[key] == true;
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

  Future<void> sendMessage(String text) async {
    final msg = text.trim();
    if (msg.isEmpty) return;
    final p = _normalizedApiPlatform(platform.value, fallback: 'twitch');
    final token = await _resolveChatAuthToken(p);
    if (token == null || token.isEmpty) return;
    _socketAuthToken = token.trim();

    _purgeStalePendingEchoes();

    final localId = 'local:${DateTime.now().microsecondsSinceEpoch}';
    _pendingLocalChatEchoes.add(
      _PendingLocalChatEcho(
        platform: p,
        normalizedText: msg.toLowerCase(),
        localMessageId: localId,
        createdAt: DateTime.now().toUtc(),
      ),
    );

    final optimistic = ChatMessage(
      platform: p,
      userName: _outgoingChatDisplayName(),
      message: msg,
      timestamp: DateTime.now().toUtc(),
      id: localId,
      raw: const <String, dynamic>{},
    );
    _appendAndSortPlatformMessages(p, optimistic);

    try {
      await _live.sendMessage(
        platform: p,
        accessToken: _socketAuthToken!,
        message: msg,
      );
    } catch (_) {
      // Drop optimistic row if send fails.
      _pendingLocalChatEchoes.removeWhere((e) => e.localMessageId == localId);
      _removeMessageById(p, localId);
    }
    _bumpScroll();
  }

  String _outgoingChatDisplayName() {
    final p = _normalizedApiPlatform(platform.value, fallback: 'twitch');
    final fromOverview = platformChatUsernames[p];
    if (fromOverview != null && fromOverview.trim().isNotEmpty) {
      return fromOverview.trim();
    }
    try {
      final me = Get.find<AuthController>().me.value;
      final u = me?['username']?.toString().trim();
      if (u != null && u.isNotEmpty) return u;
    } catch (_) {}
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

  bool _isLocalEchoId(String? id) =>
      id != null && id.startsWith('local:');

  /// Same line twice in a short window (socket echo + optimistic, or double socket).
  bool _isNearbyDuplicateContent(ChatMessage a, ChatMessage b) {
    if (a.platform.toLowerCase().trim() != b.platform.toLowerCase().trim()) {
      return false;
    }
    if (a.message.trim() != b.message.trim()) return false;
    final dt =
        (b.timestamp.toUtc().difference(a.timestamp.toUtc())).abs().inSeconds;
    if (dt > 25) return false;
    final ua = a.userName.trim().toLowerCase();
    final ub = b.userName.trim().toLowerCase();
    if (ua == ub) return true;
    if (_isLocalEchoId(a.id) || _isLocalEchoId(b.id)) return true;
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

      if (m.id != null &&
          incoming.id != null &&
          m.id == incoming.id) {
        return true;
      }
      if (_isLocalEchoId(m.id) || _isLocalEchoId(incoming.id)) {
        return true;
      }
      final dt = (incTs.difference(m.timestamp.toUtc())).abs().inSeconds;
      if (m.id == null && incoming.id == null && dt <= 3) {
        return true;
      }
    }
    return false;
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
    return (rawType ?? '').toLowerCase().trim();
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
      messageId = (metadata['messageId'] ??
                  metadata['message_id'] ??
                  metadata['id'] ??
                  '')
              .toString()
              .trim();
    }
    final type = _normalizeActivityType(event['type']?.toString());
    final ts = (event['timestamp'] ?? event['created_at'] ?? '')
        .toString()
        .trim();

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
      final oldestKeys = _edgeGlowEventSeenAt.entries.toList()
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

    final selectedPlatform = _normalizePlatformKey(platform.value);
    final eventPlatform = _normalizePlatformKey(event['platform']?.toString());

    final glowPlatform =
        eventPlatform.isNotEmpty ? eventPlatform : selectedPlatform;
    if (glowPlatform.isEmpty) return;

    final dedupeKey = _edgeGlowDedupeKeyForActivity(
      event,
      platformKey: glowPlatform,
    );
    if (_seenEdgeGlowRecently(dedupeKey)) return;

    if (kDebugMode) {
      debugPrint('[ACTIVITY_EVENT][EDGE_GLOW_TRIGGER] platform=$glowPlatform event=$event');
    }
    _edgeGlow.triggerForPlatform(glowPlatform);
  }

  /// Appends one realtime activity row (from `activity:event`, `activity:follow`, `activity:join`, …).
  void _handleIncomingActivityEvent(Map<String, dynamic> event) {
    if (kDebugMode) {
      debugPrint('[ACTIVITY_EVENT][CHAT_CONTROLLER] $event');
    }
    if (!_isActivityPayload(event)) return;
    activityEvents.add(event);
    _maybeTriggerEdgeGlowForActivity(event);
  }

  void _appendActivityFromChatMessage(
    ChatMessage msg, {
    bool triggerEdgeGlow = true,
  }) {
    final id = msg.id?.trim();
    final dedupe = id != null && id.isNotEmpty
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
      'type': _chatMessagePayloadType(msg),
      'metadata': <String, dynamic>{
        'user': msg.userName,
        'username': msg.userName,
        'message': msg.message,
      },
      'timestamp': msg.timestamp.toUtc().toIso8601String(),
      'created_at': msg.timestamp.toUtc().toIso8601String(),
    };
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
    final normalizedMsg = msg.platform == p
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
    if (_shouldSuppressSocketNearDuplicate(existing, normalizedMsg)) {
      return;
    }

    final merged = _mergeUniqueByDedupeKey(existing, <ChatMessage>[normalizedMsg]);
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
      watchUrl.value = '';
      platformMessages[key] = const <ChatMessage>[];
      if (platform.value.toLowerCase().trim() == key) {
        messages.clear();
      }
      _bumpScroll();
    } else if (cachedLive == true) {
      isLive.value = true;
      final u = platformEmbedUrls[key];
      watchUrl.value = (u != null && u.trim().isNotEmpty) ? u : '';
    } else {
      // Unknown state: avoid showing old stream while we fetch.
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

    final existingIds = <String>{
      for (final e in activityEvents)
        if (e['id'] != null) e['id'].toString().trim(),
    }..removeWhere((s) => s.isEmpty);

    final toAdd = <Map<String, dynamic>>[];
    for (final item in raw) {
      if (!_isActivityPayload(item)) continue;

      final eventPlatform = _normalizePlatformKey(item['platform']?.toString());
      if (eventPlatform.isNotEmpty && eventPlatform != platformKey) continue;

      final id = item['id']?.toString().trim() ?? '';
      if (id.isNotEmpty && existingIds.contains(id)) continue;

      final copy = Map<String, dynamic>.from(item);
      final meta = copy['metadata'];
      if (meta is Map) {
        final mm = Map<String, dynamic>.from(meta.cast<String, dynamic>());
        final login = (mm['user_login'] ??
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
      toAdd.add(copy);
    }

    if (toAdd.isEmpty) return;

    toAdd.sort(
      (a, b) => _activityEventTimeUtc(a).compareTo(_activityEventTimeUtc(b)),
    );
    for (final m in toAdd) {
      activityEvents.add(m);
    }
    activityEvents.refresh();
  }

  Future<void> _refreshHistoryForPlatform(String platformKey, {bool force = false}) {
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

  Future<void> _refreshHistoryForPlatformImpl(String key, {bool force = false}) async {
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
          _bumpScroll();
        }
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
    void addAll(List<ChatMessage> list) {
      for (final m in list) {
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

  /// Disconnect realtime chat and clear lists after full logout.
  Future<void> resetForLogout() async {
    _overviewRefreshCoalesce.clear();
    _historyRefreshCoalesce.clear();
    _connectRetryTimer?.cancel();
    _connectRetryTimer = null;
    _pendingLocalChatEchoes.clear();
    _historyLastFetchAt.clear();
    _activityChatSourceDedupeIds.clear();
    _edgeGlowEventSeenAt.clear();
    _realtimeObserversWired = false;
    try {
      await _live.disconnect();
    } catch (_) {}
    _socketAuthToken = null;
    _socketBaseUrl = null;
    _socketPath = null;
    _socketConnectedPlatform = null;
    _socketConnectedToken = null;
    platformMessages.clear();
    messages.clear();
    activityEvents.clear();
    platformViewerCounts.clear();
    platformLive.clear();
    platformEmbedUrls.clear();
    platformChatUsernames.clear();
    streamTitleByPlatform.clear();
    streamCategoryByPlatform.clear();
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
      _socketConnectedPlatform =
          _normalizedApiPlatform(platform.value, fallback: 'twitch');
      _socketConnectedToken = _socketAuthToken;
      final selected = _normalizedApiPlatform(platform.value, fallback: 'twitch');
      if (selected.isNotEmpty) {
        // Overview’s `_ensureChatForLivePlatform` usually loads history; avoid a second immediate GET.
        unawaited(_refreshHistoryForPlatform(selected, force: false));
      }
    };
    _live.onSocketDisconnected = (_) {
      isConnected.value = false;
      _socketConnectedPlatform = null;
      _socketConnectedToken = null;
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
      }
    };
    _live.onViewerCountUpdate = (p, vc) {
      final key = _normalizedApiPlatform(p);
      if (key.isEmpty) return;
      platformViewerCounts[key] = vc;
      platformViewerCounts.refresh();
      if (key ==
          _normalizedApiPlatform(platform.value, fallback: 'twitch')) {
        viewerCount.value = vc;
      }
      if (kDebugMode) {
        debugPrint(
          '[SC_STREAM_DETAILS] viewer_count:update platform=$key count=$vc',
        );
      }
    };
    _live.onLiveUpdate = (p, live) {
      final key = _normalizedApiPlatform(p);
      if (key.isEmpty) return;
      platformLive[key] = live;
      platformLive.refresh();
      final selected = _normalizedApiPlatform(platform.value, fallback: 'twitch');
      if (key != selected) return;

      if (!live) {
        isLive.value = false;
        watchUrl.value = '';
        platformMessages[selected] = const <ChatMessage>[];
        messages.clear();
        _bumpScroll();
      } else {
        isLive.value = true;
        final u = platformEmbedUrls[selected];
        if (u != null && u.trim().isNotEmpty) watchUrl.value = u;
        unawaited(_ensureChatForLivePlatform(selected));
      }
      _logStreamSnapshot('socket:live_state');
    };
    _live.onPlayerUrlUpdate = (p, url) {
      final key = _normalizedApiPlatform(p);
      if (key.isEmpty) return;
      platformEmbedUrls[key] = url;
      platformEmbedUrls.refresh();
      final selected = _normalizedApiPlatform(platform.value, fallback: 'twitch');
      if (key == selected && (url?.trim().isNotEmpty == true) && isPlatformLive(selected)) {
        watchUrl.value = url;
        isLive.value = true;
      }
      _logStreamSnapshot('socket:player_url');
    };
    _live.onActivitySync = (events) {
      if (events.isEmpty) return;
      final filtered = events
          .where((e) => _isActivityPayload(e))
          .toList(growable: false);
      if (filtered.isNotEmpty) {
        activityEvents.assignAll(filtered);
      }
    };
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
    void applyMeta(Map<String, dynamic> m) {
      final p = _normalizedApiPlatform((m['platform'] ?? '').toString());
      if (p.isEmpty) return;
      Map<String, dynamic>? meta;
      final rawMeta = m['meta'];
      if (rawMeta is Map) meta = rawMeta.cast<String, dynamic>();
      final title = (meta?['title'] ?? m['title'])?.toString().trim();
      final category = (meta?['category'] ?? m['category'])?.toString().trim();
      if (title != null && title.isNotEmpty) streamTitleByPlatform[p] = title;
      if (category != null && category.isNotEmpty) streamCategoryByPlatform[p] = category;
      streamTitleByPlatform.refresh();
      streamCategoryByPlatform.refresh();
      _logStreamSnapshot('socket:stream_meta');
    }
    _live.onStreamStatus = applyMeta;
    _live.onStreamInfoUpdate = applyMeta;
    _live.onChatMessage = _handleIncomingChatMessage;
  }

  /// Public: always fetch latest chat history from server (no UI caching).
  /// Socket messages are still appended in realtime, but this ensures you don't
  /// miss messages after reconnect or backgrounding.
  Future<void> refreshChatHistory({String? forPlatform, bool force = true}) {
    final key =
        _normalizedApiPlatform(forPlatform ?? platform.value, fallback: 'twitch');
    return _refreshHistoryForPlatform(key, force: force);
  }

  /// Switch selected platform immediately using cached state while refresh runs.
  void selectPlatformInstant(String p) {
    try {
      final key = _normalizedApiPlatform(p, fallback: 'twitch');
      if (key.isEmpty) return;

      final cachedLive = platformLive[key];
      final cachedUrl = platformEmbedUrls[key];
      if (cachedLive == true) {
        isLive.value = true;
        watchUrl.value = (cachedUrl != null && cachedUrl.trim().isNotEmpty)
            ? cachedUrl
            : '';
      } else if (cachedLive == false) {
        isLive.value = false;
        watchUrl.value = '';
      } else {
        isLive.value = false;
        watchUrl.value = (cachedUrl != null && cachedUrl.trim().isNotEmpty)
            ? cachedUrl
            : '';
      }

      messages.assignAll(platformMessages[key] ?? const <ChatMessage>[]);
      _bumpScroll();

      if (platform.value.toLowerCase().trim() != key) {
        platform.value = key;
      } else {
        // One round-trip: overview (REST) + chat history; avoid duplicate swap/history work.
        unawaited(refreshOverviewForPlatform(key, forceChatHistory: true));
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ChatController] selectPlatformInstant failed: $e');
      }
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
    _socketConnectedPlatform = null;
    _socketConnectedToken = null;
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
