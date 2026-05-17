import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../api/platforms/platforms_api.dart';
import 'auth_controller.dart';
import '../core/utils/platform_token_provider.dart';

/// Cached platform category lists from REST (prefetched once after auth).
class PlatformCategoriesController extends GetxController {
  /// YouTube categories allowed for live stream assignment (matches backend).
  static const Set<String> youtubeLiveAssignableCategoryIds = {
    '1',
    '2',
    '10',
    '15',
    '17',
    '19',
    '20',
    '22',
    '23',
    '24',
    '25',
    '26',
    '27',
    '28',
    '29',
  };

  PlatformCategoriesController({
    PlatformsApi? platformsApi,
    AuthController? auth,
    PlatformTokenProvider? tokenProvider,
  })  : _platforms = platformsApi ?? Get.find<AuthController>().api.platforms,
        _auth = auth ?? Get.find<AuthController>(),
        _tokenProvider = tokenProvider ?? PlatformTokenProvider();

  final PlatformsApi _platforms;
  final AuthController _auth;
  final PlatformTokenProvider _tokenProvider;

  final RxMap<String, List<Map<String, String>>> categoriesByPlatform =
      <String, List<Map<String, String>>>{}.obs;

  final RxMap<String, bool> loadingByPlatform = <String, bool>{}.obs;

  final Map<String, Future<void>> _inFlightByPlatform = {};
  final Map<String, Timer?> _searchDebounceTimers = {};
  final Map<String, TextEditingController> _searchControllers = {};

  bool _prefetchInFlight = false;
  bool _suppressSearchListener = false;

  static const Duration _searchDebounce = Duration(milliseconds: 350);

  bool supportsCategorySearch(String platform) {
    final key = _normalizePlatform(platform);
    return key == 'twitch' || key == 'kick';
  }

  TextEditingController searchControllerFor(String platform) {
    final key = _normalizePlatform(platform);
    return _searchControllers.putIfAbsent(key, () {
      final controller = TextEditingController();
      controller.addListener(() {
        if (_suppressSearchListener) return;
        _scheduleCategorySearch(key, controller.text);
      });
      return controller;
    });
  }

  List<Map<String, String>> categoriesFor(String platform) {
    final key = _normalizePlatform(platform);
    if (key.isEmpty) return const [];
    return _visibleCategoriesForPlatform(
      key,
      categoriesByPlatform[key] ?? const [],
    );
  }

  static List<Map<String, String>> _visibleCategoriesForPlatform(
    String platformKey,
    List<Map<String, String>> items,
  ) {
    if (platformKey != 'youtube') {
      return List<Map<String, String>>.from(items);
    }
    return items
        .where((item) {
          final id = (item['id'] ?? '').trim();
          return youtubeLiveAssignableCategoryIds.contains(id);
        })
        .toList(growable: false);
  }

  bool isLoading(String platform) {
    final key = _normalizePlatform(platform);
    return loadingByPlatform[key] == true;
  }

  /// Loads Twitch / Kick / YouTube lists once per session (also safe to call again).
  Future<void> prefetchAllIfNeeded() async {
    if (_prefetchInFlight) return;
    if (!_auth.isAuthenticated.value) return;

    _prefetchInFlight = true;
    try {
      await _auth.ensureValidSession(refreshIfExpired: true);
      await Future.wait<void>([
        ensureCategoriesFor('twitch'),
        ensureCategoriesFor('kick'),
        ensureCategoriesFor('youtube'),
      ], eagerError: false);
    } finally {
      _prefetchInFlight = false;
    }
  }

  /// Fetches categories for one platform if cache is empty (e.g. when opening the picker).
  Future<void> ensureCategoriesFor(
    String platform, {
    bool force = false,
  }) {
    final key = _normalizePlatform(platform);
    if (key.isEmpty) return Future.value();
    if (!force && categoriesByPlatform[key]?.isNotEmpty == true) {
      return Future.value();
    }

    return _fetchCategories(key);
  }

  /// Clears Twitch/Kick search and loads default `chat` / `irl` results.
  Future<void> resetAndLoadCategories(String platform) {
    final key = _normalizePlatform(platform);
    if (key.isEmpty) return Future.value();
    _clearSearchField(key);
    return _fetchCategories(key, searchQuery: null);
  }

  void _scheduleCategorySearch(String key, String rawQuery) {
    if (!supportsCategorySearch(key)) return;
    _searchDebounceTimers[key]?.cancel();
    _searchDebounceTimers[key] = Timer(_searchDebounce, () {
      _searchDebounceTimers.remove(key);
      unawaited(_fetchCategories(key, searchQuery: rawQuery.trim()));
    });
  }

  void _clearSearchField(String key) {
    _suppressSearchListener = true;
    try {
      final controller = _searchControllers[key];
      if (controller != null && controller.text.isNotEmpty) {
        controller.text = '';
      }
    } finally {
      _suppressSearchListener = false;
    }
  }

  Future<void> _fetchCategories(String key, {String? searchQuery}) {
    final inFlightKey = _inFlightKey(key, searchQuery);
    final pending = _inFlightByPlatform[inFlightKey];
    if (pending != null) return pending;

    final run = _fetchAndStore(key, searchQuery: searchQuery);
    _inFlightByPlatform[inFlightKey] = run;
    return run.whenComplete(() => _inFlightByPlatform.remove(inFlightKey));
  }

  static String _inFlightKey(String platformKey, String? searchQuery) {
    final trimmed = searchQuery?.trim() ?? '';
    if (trimmed.isEmpty) return '$platformKey|_default_';
    return '$platformKey|$trimmed';
  }

  Future<void> _fetchAndStore(String key, {String? searchQuery}) async {
    if (!_auth.isAuthenticated.value) return;
    loadingByPlatform[key] = true;
    loadingByPlatform.refresh();
    try {
      await _auth.ensureValidSession(refreshIfExpired: true);

      final queryParams = _queryParamsForPlatform(key, searchQuery: searchQuery);

      // Same Dio as other authenticated REST: session JWT via [AuthInterceptor] only.
      var items = await _platforms.fetchCategories(
        platform: key,
        query: queryParams.query,
        first: queryParams.first,
        limit: queryParams.limit,
        region: queryParams.region,
      );

      if (items.isEmpty) {
        final platformToken = await _tokenProvider.getAccessToken(key);
        if (platformToken != null && platformToken.trim().isNotEmpty) {
          items = await _platforms.fetchCategories(
            platform: key,
            accessToken: platformToken.trim(),
            query: queryParams.query,
            first: queryParams.first,
            limit: queryParams.limit,
            region: queryParams.region,
          );
        }
      }

      if (kDebugMode) {
        debugPrint(
          '[PlatformCategories] $key loaded ${items.length} categories',
        );
      }

      final visible = _visibleCategoriesForPlatform(key, items);
      categoriesByPlatform[key] = visible;
      categoriesByPlatform.refresh();
    } finally {
      loadingByPlatform[key] = false;
      loadingByPlatform.refresh();
    }
  }

  static _CategoryQuery _queryParamsForPlatform(
    String key, {
    String? searchQuery,
  }) {
    final trimmed = searchQuery?.trim() ?? '';
    switch (key) {
      case 'twitch':
        return _CategoryQuery(
          query: trimmed.isNotEmpty ? trimmed : 'chat',
          first: 20,
        );
      case 'kick':
        return _CategoryQuery(
          query: trimmed.isNotEmpty ? trimmed : 'irl',
          limit: 20,
        );
      case 'youtube':
        return const _CategoryQuery(region: 'US');
      default:
        return const _CategoryQuery();
    }
  }

  @override
  void onClose() {
    for (final timer in _searchDebounceTimers.values) {
      timer?.cancel();
    }
    _searchDebounceTimers.clear();
    for (final controller in _searchControllers.values) {
      controller.dispose();
    }
    _searchControllers.clear();
    super.onClose();
  }

  static String _normalizePlatform(String raw) {
    final v = raw.toLowerCase().trim();
    if (v.contains('youtube') || v == 'yt') return 'youtube';
    if (v.contains('twitch')) return 'twitch';
    if (v.contains('kick')) return 'kick';
    return v;
  }
}

class _CategoryQuery {
  const _CategoryQuery({this.query, this.first, this.limit, this.region});

  final String? query;
  final int? first;
  final int? limit;
  final String? region;
}
