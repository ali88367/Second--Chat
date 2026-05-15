import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../api/platforms/platforms_api.dart';
import 'auth_controller.dart';
import '../core/utils/platform_token_provider.dart';

/// Cached platform category lists from REST (prefetched once after auth).
class PlatformCategoriesController extends GetxController {
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

  bool _prefetchInFlight = false;

  List<Map<String, String>> categoriesFor(String platform) {
    final key = _normalizePlatform(platform);
    if (key.isEmpty) return const [];
    return List<Map<String, String>>.from(categoriesByPlatform[key] ?? const []);
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

    final pending = _inFlightByPlatform[key];
    if (pending != null) return pending;

    final run = _fetchAndStore(key);
    _inFlightByPlatform[key] = run;
    return run.whenComplete(() => _inFlightByPlatform.remove(key));
  }

  Future<void> _fetchAndStore(String key) async {
    if (!_auth.isAuthenticated.value) return;
    loadingByPlatform[key] = true;
    loadingByPlatform.refresh();
    try {
      await _auth.ensureValidSession(refreshIfExpired: true);

      final queryParams = _queryParamsForPlatform(key);

      // Prefer backend session JWT (AuthInterceptor). Platform OAuth tokens can 401 here.
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

      if (items.isEmpty) return;
      categoriesByPlatform[key] = items;
      categoriesByPlatform.refresh();
    } finally {
      loadingByPlatform[key] = false;
      loadingByPlatform.refresh();
    }
  }

  static _CategoryQuery _queryParamsForPlatform(String key) {
    switch (key) {
      case 'twitch':
        return const _CategoryQuery(query: 'chat', first: 20);
      case 'kick':
        return const _CategoryQuery(query: 'irl', limit: 20);
      case 'youtube':
        return const _CategoryQuery(region: 'US');
      default:
        return const _CategoryQuery();
    }
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
