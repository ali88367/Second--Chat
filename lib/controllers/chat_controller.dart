import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

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
  final LiveStreamService _live;

  final RxString platform = 'twitch'.obs;

  final RxnString watchUrl = RxnString();
  final RxBool isLive = false.obs;
  final Rxn<StreamingOverview> overview = Rxn<StreamingOverview>();
  final RxMap<String, int> platformViewerCounts = <String, int>{}.obs;
  final RxMap<String, bool> platformLive = <String, bool>{}.obs;
  final RxMap<String, String?> platformEmbedUrls = <String, String?>{}.obs;
  final RxMap<String, String?> streamTitleByPlatform = <String, String?>{}.obs;
  final RxMap<String, String?> streamCategoryByPlatform =
      <String, String?>{}.obs;
  final RxList<Map<String, dynamic>> activityEvents =
      <Map<String, dynamic>>[].obs;

  Timer? _connectRetryTimer;
  bool _realtimeObserversWired = false;
  bool _socketConnecting = false;
  DateTime _lastSocketConnectAttempt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastPlatformSocketSwitchAttempt = DateTime.fromMillisecondsSinceEpoch(0);
  final Set<String> _historyInFlight = <String>{};
  final Map<String, DateTime> _historyLastFetchAt = <String, DateTime>{};

  final RxList<ChatMessage> messages = <ChatMessage>[].obs;
  final RxInt viewerCount = 0.obs;
  final RxBool isConnected = false.obs;

  final RxInt scrollTick = 0.obs; // UI can observe this to auto-scroll.

  String? _accessToken;
  String? _socketBaseUrl;
  String? _socketPath;

  @override
  void onInit() {
    super.onInit();
    _wireServiceCallbacks();
    _bootstrap();

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

      final token = _accessToken ??
          await _live.ensureFreshPlatformAccessToken(platform: platform.value) ??
          await _tokenProvider.getAccessToken(platform.value);
      if (token == null || token.trim().isEmpty) return;
      _accessToken = token.trim();

      // Ensure we have socketUrl/socketPath in `overview`.
      var socketUrl = _socketBaseUrl;
      var socketPath = _socketPath;

      final hasSocketFields = socketUrl != null &&
          socketUrl.trim().isNotEmpty &&
          socketPath != null &&
          socketPath.trim().isNotEmpty;

      if (!hasSocketFields) {
        // Refresh only the selected platform overview; it also updates socketUrl/path.
        await refreshOverviewForPlatform(platform.value);
        socketUrl = _socketBaseUrl;
        socketPath = _socketPath;
      }

      if (socketUrl == null ||
          socketUrl.trim().isEmpty ||
          socketPath == null ||
          socketPath.trim().isEmpty) {
        return;
      }

      await _live.connect(
        baseUrl: socketUrl.trim(),
        path: socketPath.trim(),
        accessToken: _accessToken!,
        label: platform.value.toLowerCase(),
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

  Future<void> _bootstrap() async {
    try {
      // 1) App start: hit overview for each connected platform (tokens in SharedPrefs).
      final connectedPlatforms = await _tokenProvider.getConnectedPlatforms();
      if (connectedPlatforms.isNotEmpty) {
        // Keep default selection as-is unless it's not connected.
        final selected = platform.value.toLowerCase();
        if (!connectedPlatforms.contains(selected)) {
          platform.value = connectedPlatforms.first;
        }
        await refreshOverviewsForPlatforms(connectedPlatforms);
      }

      // Keep a main access token for socket auth (typically app JWT).
      _accessToken = await _tokenProvider.getAccessToken(platform.value);
      if (_accessToken == null || _accessToken!.isEmpty) return;

      final history = await _live.loadHistory(
        platform: platform.value,
        accessToken: _accessToken!,
      );
      if (history.isNotEmpty) {
        messages.assignAll(history);
        _bumpScroll();
      }

      // Ensure we have socketUrl/path even if connectedPlatforms was empty.
      if (overview.value == null) {
        await refreshOverviewForPlatform(platform.value);
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
          accessToken: _accessToken!,
          label: platform.value.toLowerCase(),
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
      // Fallback token (some backends accept the same JWT for all platforms).
      final fallbackToken =
          (_accessToken?.trim().isNotEmpty == true)
              ? _accessToken!.trim()
              : null;
      for (final p in normalized) {
        // Each platform has its own token.
        final pToken = await _tokenProvider.getAccessToken(p);
        final effectiveToken =
            (pToken != null && pToken.trim().isNotEmpty)
                ? pToken.trim()
                : fallbackToken;
        if (kDebugMode) {
          debugPrint(
            '[ChatController] overview token platform=$p present=${pToken != null && pToken.trim().isNotEmpty} '
            'fallbackUsed=${(pToken == null || pToken.trim().isEmpty) && (fallbackToken != null)} '
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
        raw: primary.raw,
      );

      if (mergedViewer.isNotEmpty) platformViewerCounts.assignAll(mergedViewer);
      if (mergedLive.isNotEmpty) platformLive.assignAll(mergedLive);
      if (mergedEmbed.isNotEmpty) platformEmbedUrls.assignAll(mergedEmbed);

      // Update currently selected stream URL.
      final currentUrl = mergedEmbed[current] ?? primary.watchUrl;
      watchUrl.value = currentUrl;
      isLive.value = mergedLive[current] ?? primary.live;
    } catch (_) {}
  }

  String _maskToken(String? token) {
    final t = token?.trim() ?? '';
    if (t.isEmpty) return '(empty)';
    if (t.length <= 10) return '(${t.length} chars)';
    return '${t.substring(0, 6)}…${t.substring(t.length - 4)} (${t.length} chars)';
  }

  Future<void> refreshOverviewForPlatform(String p) async {
    try {
      final token = await _live.ensureFreshPlatformAccessToken(platform: p) ??
          await _tokenProvider.getAccessToken(p);
      if (token == null || token.isEmpty) return;
      _accessToken = token.trim();

      // If multi-preview mode is enabled, refresh all platforms so the top streams stay "hot".
      if (_settings.multiScreenPreview.value == true) {
        if (kDebugMode) {
          debugPrint('[ChatController] multiScreenPreview=ON; refreshing all');
        }
        await refreshOverviewsForPlatforms(const ['twitch', 'kick', 'youtube']);
        // selected platform state still needs to update.
        platform.value = p;
        unawaited(_switchSocketToPlatform(p));
        final key = p.toLowerCase();
        isLive.value = platformLive[key] ?? isLive.value;
        watchUrl.value = platformEmbedUrls[key] ?? watchUrl.value;
        if (isLive.value == true) {
          unawaited(_ensureChatForLivePlatform(key));
        }
        return;
      }

      final ov = await _live.fetchOverview(
        platform: p,
        accessToken: token,
      );
      if (ov == null) return;
      overview.value = ov;
      _socketBaseUrl = ov.chatSocketUrl ?? _socketBaseUrl;
      _socketPath = ov.chatSocketPath ?? _socketPath;
      // selected platform state
      platform.value = p;
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
        unawaited(_ensureChatForLivePlatform(p.toLowerCase()));
      }
    } catch (_) {}
  }

  Future<void> _switchSocketToPlatform(String p) async {
    final key = p.toLowerCase().trim();
    if (key.isEmpty) return;
    // Debounce platform socket switching (chip tap + swipe can fire quickly).
    final now = DateTime.now();
    if (now.difference(_lastPlatformSocketSwitchAttempt) <
        const Duration(milliseconds: 600)) {
      return;
    }
    _lastPlatformSocketSwitchAttempt = now;

    final token = await _live.ensureFreshPlatformAccessToken(platform: key) ??
        await _tokenProvider.getAccessToken(key);
    if (token == null || token.trim().isEmpty) return;
    _accessToken = token.trim();

    // Ensure socket url/path is available (from last overview fetch).
    final socketUrl = _socketBaseUrl;
    final socketPath = _socketPath;
    if (socketUrl == null ||
        socketUrl.trim().isEmpty ||
        socketPath == null ||
        socketPath.trim().isEmpty) {
      return;
    }

    // Disconnect previous socket and connect again with new platform token.
    try {
      await _live.disconnect();
    } catch (_) {}
    await _live.connect(
      baseUrl: socketUrl.trim(),
      path: socketPath.trim(),
      accessToken: _accessToken!,
      label: key,
    );
  }

  bool isPlatformLive(String p) {
    return platformLive[p.toLowerCase()] == true;
  }

  String? urlForPlatform(String p) {
    return platformEmbedUrls[p.toLowerCase()];
  }

  Future<void> sendMessage(String text) async {
    final msg = text.trim();
    if (msg.isEmpty) return;
    final token =
        _accessToken ?? await _tokenProvider.getAccessToken(platform.value);
    if (token == null || token.isEmpty) return;

    await _live.sendMessage(platform: platform.value, accessToken: token, message: msg);
    _bumpScroll();
  }

  Future<void> _ensureChatForLivePlatform(String p) async {
    final key = p.toLowerCase();
    // 1) Socket ensure connect (no-op if already connected)
    if (isConnected.value != true) {
      await _tryConnectIfPossible();
    }

    // 2) History fetch with cooldown + in-flight guard (optimized)
    if (_historyInFlight.contains(key)) return;
    final now = DateTime.now().toUtc();
    final last = _historyLastFetchAt[key];
    // Avoid frequent history hits while stream status flaps.
    if (last != null && now.difference(last) < const Duration(seconds: 20)) {
      return;
    }

    final token = _accessToken ??
        await _live.ensureFreshPlatformAccessToken(platform: key) ??
        await _tokenProvider.getAccessToken(key);
    if (token == null || token.isEmpty) return;

    _historyInFlight.add(key);
    try {
      final history = await _live.loadHistory(
        platform: key,
        accessToken: token,
        limit: 100,
        offset: 0,
      );
      if (history.isNotEmpty) {
        // Merge without duplicates.
        final existingKeys = messages
            .map((m) => '${m.platform.toLowerCase()}|${m.id ?? ''}|${m.message}|${m.timestamp.toUtc().millisecondsSinceEpoch}')
            .toSet();
        final toAdd = history.where((m) {
          final k = '${m.platform.toLowerCase()}|${m.id ?? ''}|${m.message}|${m.timestamp.toUtc().millisecondsSinceEpoch}';
          return !existingKeys.contains(k);
        }).toList(growable: false);
        if (toAdd.isNotEmpty) {
          messages.addAll(toAdd);
          _bumpScroll();
        }
      }
      _historyLastFetchAt[key] = now;
    } catch (_) {
      // silent
    } finally {
      _historyInFlight.remove(key);
    }
  }

  void _bumpScroll() {
    // Cheap observable tick for UI that can't easily diff RxList changes.
    scrollTick.value++;
  }

  void _wireServiceCallbacks() {
    _live.onSocketConnected = () {
      isConnected.value = true;
    };
    _live.onSocketDisconnected = (_) {
      isConnected.value = false;
    };
    _live.onSocketError = (m) async {
      final msg = (m['message'] ?? '').toString();
      if (msg.contains('Invalid authentication token') ||
          msg.contains('Authentication token required')) {
        // Refresh platform token and retry connect quickly.
        final selected = platform.value.toLowerCase();
        final fresh =
            await _live.ensureFreshPlatformAccessToken(platform: selected);
        if (fresh != null && fresh.trim().isNotEmpty) {
          _accessToken = fresh.trim();
          await refreshOverviewForPlatform(selected);
          unawaited(_tryConnectIfPossible());
        }
      }
    };
    _live.onViewerCountUpdate = (p, vc) {
      platformViewerCounts[p] = vc;
      if (p == platform.value.toLowerCase()) viewerCount.value = vc;
    };
    _live.onLiveUpdate = (p, live) {
      platformLive[p] = live;
      final selected = platform.value.toLowerCase();
      if (p != selected) return;

      if (!live) {
        isLive.value = false;
        watchUrl.value = '';
        messages.removeWhere((msg) => msg.platform.toLowerCase() == selected);
        _bumpScroll();
      } else {
        isLive.value = true;
        final u = platformEmbedUrls[selected];
        if (u != null && u.trim().isNotEmpty) watchUrl.value = u;
        unawaited(_ensureChatForLivePlatform(selected));
      }
    };
    _live.onPlayerUrlUpdate = (p, url) {
      platformEmbedUrls[p] = url;
      final selected = platform.value.toLowerCase();
      if (p == selected && (url?.trim().isNotEmpty == true) && isPlatformLive(selected)) {
        watchUrl.value = url;
        isLive.value = true;
      }
    };
    _live.onActivitySync = (events) {
      if (events.isNotEmpty) activityEvents.assignAll(events);
    };
    _live.onActivityEvent = (e) {
      activityEvents.add(e);
    };
    void applyMeta(Map<String, dynamic> m) {
      final p = (m['platform'] ?? '').toString().toLowerCase();
      if (p.isEmpty) return;
      Map<String, dynamic>? meta;
      final rawMeta = m['meta'];
      if (rawMeta is Map) meta = rawMeta.cast<String, dynamic>();
      final title = (meta?['title'] ?? m['title'])?.toString().trim();
      final category = (meta?['category'] ?? m['category'])?.toString().trim();
      if (title != null && title.isNotEmpty) streamTitleByPlatform[p] = title;
      if (category != null && category.isNotEmpty) streamCategoryByPlatform[p] = category;
    }
    _live.onStreamStatus = applyMeta;
    _live.onStreamInfoUpdate = applyMeta;
    _live.onChatMessage = (msg) {
      messages.add(msg);
      _bumpScroll();
    };
  }

  @override
  void onClose() {
    _connectRetryTimer?.cancel();
    _connectRetryTimer = null;
    _historyInFlight.clear();
    _historyLastFetchAt.clear();
    try {
      _live.disconnect();
    } catch (_) {}
    super.onClose();
  }
}
