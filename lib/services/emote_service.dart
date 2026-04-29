import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../api/app_api.dart';
import '../api/auth/google_sign_in_service.dart';
import '../api/config/api_config.dart';
import '../controllers/auth_controller.dart';
import '../core/utils/platform_token_provider.dart';

/// Represents a single emote with its metadata
class Emote {
  final String id;
  final String name;
  final String url;

  const Emote({
    required this.id,
    required this.name,
    required this.url,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
  };

  factory Emote.fromJson(Map<String, dynamic> json) {
    return Emote(
      id: json['id'] as String,
      name: json['name'] as String,
      url: json['url'] as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Emote && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// GetX Service for fetching and caching 7TV global emotes
///
/// Usage:
/// ```dart
/// // Initialize once (in main or when entering live screen)
/// Get.put(EmoteService());
///
/// // Access anywhere
/// final emoteService = Get.find<EmoteService>();
/// ```
class EmoteService extends GetxController {
  static const String _cacheKey = '7tv_global_emotes';
  static const String _twitchCacheKey = 'twitch_global_emotes';
  static const String _recentKey = '7tv_recently_used';
  static const String _apiUrl = 'https://7tv.io/v3/emote-sets/global';
  static const String _twitchGlobalApiPath = '/api/v1/twitch/chat/emotes';
  static const int _maxRecentEmotes = 24;
  static const int _minTwitchEmotes = 30;
  final PlatformTokenProvider _tokenProvider = PlatformTokenProvider();
  final AppApi _appApi = AppApi.create();

  // Reactive state
  final RxMap<String, Emote> _emoteMap = <String, Emote>{}.obs;
  final RxMap<String, Emote> _twitchEmoteMap = <String, Emote>{}.obs;
  final RxList<Emote> emoteList = <Emote>[].obs;
  final RxList<Emote> twitchEmoteList = <Emote>[].obs;
  final RxBool isLoading = true.obs;
  final RxBool isTwitchLoading = true.obs;
  final RxBool hasError = false.obs;
  final RxBool hasTwitchError = false.obs;
  final RxString errorMessage = ''.obs;
  final RxString twitchErrorMessage = ''.obs;
  final RxList<String> recentlyUsedNames = <String>[].obs;

  /// Map of emote name -> emote URL for quick lookup during parsing
  Map<String, String> get emoteUrlMap =>
      _emoteMap.map((key, value) => MapEntry(key, value.url));
  Map<String, String> get twitchEmoteUrlMap =>
      _twitchEmoteMap.map((key, value) => MapEntry(key, value.url));

  /// Get emote by name (case-sensitive)
  Emote? getEmote(String name) => _emoteMap[name];
  Emote? getTwitchEmote(String name) => _twitchEmoteMap[name];

  @override
  void onInit() {
    super.onInit();
    _initializeEmotes();
  }

  /// Initialize emotes: load from cache, then fetch fresh data
  Future<void> _initializeEmotes() async {
    isLoading.value = true;
    isTwitchLoading.value = true;
    hasError.value = false;
    hasTwitchError.value = false;

    // Load from cache first for instant display
    await _loadFromCache();
    await _loadTwitchFromCache();
    await _loadRecentlyUsed();

    // Fetch fresh data from API
    await Future.wait([
      fetchEmotes(),
      fetchTwitchEmotes(),
    ]);
  }

  /// Manually refresh emotes from API
  Future<void> fetchEmotes() async {
    try {
      final response = await http
          .get(Uri.parse(_apiUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final emotesData = data['emotes'] as List<dynamic>? ?? [];

        final Map<String, Emote> newEmotes = {};

        for (final emoteData in emotesData) {
          try {
            final emote = _parseEmoteData(emoteData as Map<String, dynamic>);
            if (emote != null) {
              newEmotes[emote.name] = emote;
            }
          } catch (e) {
            debugPrint('Failed to parse emote: $e');
          }
        }

        if (newEmotes.isNotEmpty) {
          _emoteMap.assignAll(newEmotes);
          // Sort alphabetically for consistent display
          emoteList.assignAll(
            newEmotes.values.toList()..sort((a, b) => a.name.compareTo(b.name)),
          );
          hasError.value = false;
          errorMessage.value = '';
          await _saveToCache();
        }
      } else {
        _handleError('API returned status ${response.statusCode}');
      }
    } catch (e) {
      _handleError('Network error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Fetch Twitch global emotes from backend API.
  Future<void> fetchTwitchEmotes() async {
    try {
      final resolved = await _resolveFreshTwitchBearerToken();
      var token = resolved.$1;
      var source = resolved.$2;
      if (token == null || token.isEmpty) {
        _handleTwitchError('Missing Twitch/Google access token');
        return;
      }
      debugPrint('EmoteService Twitch token source: $source');

      Future<http.Response> fetchWithToken(String bearer) {
        return http
            .get(
              Uri.parse('${ApiConfig.baseUrl}$_twitchGlobalApiPath?global=true'),
              headers: <String, String>{
                'Authorization': 'Bearer $bearer',
                'Accept': 'application/json',
              },
            )
            .timeout(const Duration(seconds: 10));
      }

      var response = await fetchWithToken(token);
      if (response.statusCode == 401 || response.statusCode == 403) {
        // Token might have expired between refresh and request; refresh once more and retry.
        final retryResolved = await _resolveFreshTwitchBearerToken(force: true);
        final retryToken = retryResolved.$1;
        final retrySource = retryResolved.$2;
        if (retryToken != null && retryToken.isNotEmpty && retryToken != token) {
          token = retryToken;
          source = '$source -> $retrySource';
          debugPrint('EmoteService Twitch token retried with source: $source');
          response = await fetchWithToken(token);
        }
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final emotesData = _extractTwitchEmotesArray(data);
        final Map<String, Emote> newEmotes = {};
        for (final emoteData in emotesData) {
          try {
            final emote = _parseTwitchEmoteData(emoteData as Map<String, dynamic>);
            if (emote != null) {
              newEmotes[emote.name] = emote;
            }
          } catch (e) {
            debugPrint('Failed to parse twitch emote: $e');
          }
        }

        if (newEmotes.length >= _minTwitchEmotes) {
          _twitchEmoteMap.assignAll(newEmotes);
          twitchEmoteList.assignAll(
            newEmotes.values.toList()..sort((a, b) => a.name.compareTo(b.name)),
          );
          hasTwitchError.value = false;
          twitchErrorMessage.value = '';
          await _saveTwitchToCache();
        } else {
          _handleTwitchError(
            'Twitch returned only ${newEmotes.length} emotes (need at least $_minTwitchEmotes)',
          );
        }
      } else {
        _handleTwitchError(
          'Twitch backend API returned status ${response.statusCode} (token source: $source)',
        );
      }
    } catch (e) {
      _handleTwitchError('Twitch network error: $e');
    } finally {
      isTwitchLoading.value = false;
    }
  }

  Future<(String?, String)> _resolveTwitchBearerToken() async {
    // Keep auth aligned with the rest of app APIs: prefer backend session JWT.
    try {
      if (Get.isRegistered<AuthController>()) {
        final auth = Get.find<AuthController>();
        await auth.ensureValidSession(refreshIfExpired: true);
        final session = await auth.api.tokenStore.read();
        final appJwt = session?.accessToken.trim();
        if (appJwt != null && appJwt.isNotEmpty) {
          return (appJwt, 'session_jwt');
        }
      }
    } catch (_) {}

    // Fallback to token store (same source used by app session machinery).
    try {
      final session = await _appApi.tokenStore.read();
      final appJwt = session?.accessToken.trim();
      if (appJwt != null && appJwt.isNotEmpty) {
        return (appJwt, 'session_jwt_store');
      }
    } catch (_) {}

    final google =
        (await GoogleSignInService.instance.readStoredGoogleAccessToken())
            ?.trim();
    if (google != null && google.isNotEmpty) {
      return (google, 'google');
    }
    final twitch = (await _tokenProvider.getAccessToken('twitch'))?.trim();
    if (twitch != null && twitch.isNotEmpty) {
      return (twitch, 'platform:twitch');
    }
    return (null, 'none');
  }

  Future<(String?, String)> _resolveFreshTwitchBearerToken({
    bool force = true,
  }) async {
    // Always prefer a freshly refreshed Twitch platform token for emote endpoint.
    if (force) {
      try {
        final refreshToken = (await _tokenProvider.getRefreshToken('twitch'))
            ?.trim();
        if (refreshToken != null && refreshToken.isNotEmpty) {
          final refreshed = await _appApi.auth.refresh(refreshToken);
          final refreshedAccess = refreshed.accessToken.trim();
          final refreshedRefresh = refreshed.refreshToken.trim();
          if (refreshedAccess.isNotEmpty && refreshedRefresh.isNotEmpty) {
            await _tokenProvider.setPlatformTokens(
              platform: 'twitch',
              accessToken: refreshedAccess,
              refreshToken: refreshedRefresh,
            );
            return (refreshedAccess, 'platform:twitch_refreshed');
          }
        }
      } catch (e) {
        debugPrint('EmoteService Twitch refresh failed: $e');
      }
    }

    // Fallback to existing token resolution chain if refresh is unavailable.
    return _resolveTwitchBearerToken();
  }

  List<dynamic> _extractTwitchEmotesArray(Map<String, dynamic> payload) {
    // Expected backend response:
    // { success: true, data: { data: [...] } }
    final topData = payload['data'];
    if (topData is Map<String, dynamic>) {
      final nested = topData['data'];
      if (nested is List) return nested;
    } else if (topData is Map) {
      final nested = topData['data'];
      if (nested is List) return nested;
    }

    // Fallback for direct Twitch Helix payloads or alternate backend wrappers.
    final direct = payload['data'];
    if (direct is List) return direct;
    return const <dynamic>[];
  }

  /// Parse a single emote from API response
  Emote? _parseEmoteData(Map<String, dynamic> emoteData) {
    final id = emoteData['id'] as String?;
    final name = emoteData['name'] as String?;

    if (id == null || name == null) return null;

    final host = emoteData['data']?['host'] as Map<String, dynamic>?;
    if (host == null) return null;

    final baseUrl = host['url'] as String?;
    final files = host['files'] as List<dynamic>?;

    if (baseUrl == null || files == null || files.isEmpty) return null;

    // Find the best quality file (prefer 3x webp, fallback to 2x or 4x)
    String? selectedFilename;
    const preferredSizes = ['3x.webp', '2x.webp', '4x.webp', '1x.webp'];

    for (final preferred in preferredSizes) {
      for (final file in files) {
        final filename = file['name'] as String?;
        if (filename == preferred) {
          selectedFilename = filename;
          break;
        }
      }
      if (selectedFilename != null) break;
    }

    // Fallback: use first webp file
    selectedFilename ??= files
        .map((f) => f['name'] as String?)
        .firstWhere(
          (name) => name?.endsWith('.webp') ?? false,
      orElse: () => files.first['name'] as String?,
    );

    if (selectedFilename == null) return null;

    // Construct full URL (baseUrl typically starts with //)
    final fullUrl = baseUrl.startsWith('//')
        ? 'https:$baseUrl/$selectedFilename'
        : '$baseUrl/$selectedFilename';

    return Emote(id: id, name: name, url: fullUrl);
  }

  Emote? _parseTwitchEmoteData(Map<String, dynamic> emoteData) {
    final id = emoteData['id']?.toString().trim();
    final name = emoteData['name']?.toString().trim();
    if (id == null || id.isEmpty || name == null || name.isEmpty) return null;

    final images = emoteData['images'] as Map<String, dynamic>?;
    final url = (images?['url_4x'] ??
            images?['url_2x'] ??
            images?['url_1x'])
        ?.toString()
        .trim();
    if (url == null || url.isEmpty) return null;

    return Emote(id: id, name: name, url: url);
  }

  void _handleError(String message) {
    debugPrint('EmoteService Error: $message');
    if (_emoteMap.isEmpty) {
      hasError.value = true;
      errorMessage.value = message;
    }
  }

  void _handleTwitchError(String message) {
    debugPrint('EmoteService Twitch Error: $message');
    if (_twitchEmoteMap.isEmpty) {
      hasTwitchError.value = true;
      twitchErrorMessage.value = message;
    }
  }

  /// Load emotes from SharedPreferences cache
  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_cacheKey);

      if (jsonStr != null) {
        final List<dynamic> jsonList = json.decode(jsonStr);
        final Map<String, Emote> cached = {};

        for (final item in jsonList) {
          final emote = Emote.fromJson(item as Map<String, dynamic>);
          cached[emote.name] = emote;
        }

        if (cached.isNotEmpty) {
          _emoteMap.assignAll(cached);
          emoteList.assignAll(
            cached.values.toList()..sort((a, b) => a.name.compareTo(b.name)),
          );
          debugPrint('Loaded ${cached.length} emotes from cache');
        }
      }
    } catch (e) {
      debugPrint('Failed to load emotes from cache: $e');
    }
  }

  Future<void> _loadTwitchFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_twitchCacheKey);

      if (jsonStr != null) {
        final List<dynamic> jsonList = json.decode(jsonStr);
        final Map<String, Emote> cached = {};

        for (final item in jsonList) {
          final emote = Emote.fromJson(item as Map<String, dynamic>);
          cached[emote.name] = emote;
        }

        if (cached.isNotEmpty) {
          _twitchEmoteMap.assignAll(cached);
          twitchEmoteList.assignAll(
            cached.values.toList()..sort((a, b) => a.name.compareTo(b.name)),
          );
          debugPrint('Loaded ${cached.length} twitch emotes from cache');
        }
      }
    } catch (e) {
      debugPrint('Failed to load twitch emotes from cache: $e');
    }
  }

  /// Save emotes to SharedPreferences cache
  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _emoteMap.values.map((e) => e.toJson()).toList();
      await prefs.setString(_cacheKey, json.encode(jsonList));
      debugPrint('Saved ${jsonList.length} emotes to cache');
    } catch (e) {
      debugPrint('Failed to save emotes to cache: $e');
    }
  }

  Future<void> _saveTwitchToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _twitchEmoteMap.values.map((e) => e.toJson()).toList();
      await prefs.setString(_twitchCacheKey, json.encode(jsonList));
      debugPrint('Saved ${jsonList.length} twitch emotes to cache');
    } catch (e) {
      debugPrint('Failed to save twitch emotes to cache: $e');
    }
  }

  /// Add an emote to recently used list
  void addToRecentlyUsed(String emoteName) {
    if (!_emoteMap.containsKey(emoteName)) return;

    recentlyUsedNames.remove(emoteName);
    recentlyUsedNames.insert(0, emoteName);

    if (recentlyUsedNames.length > _maxRecentEmotes) {
      recentlyUsedNames.removeRange(_maxRecentEmotes, recentlyUsedNames.length);
    }

    _saveRecentlyUsed();
  }

  Future<void> _loadRecentlyUsed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_recentKey) ?? [];
      recentlyUsedNames.assignAll(list);
    } catch (e) {
      debugPrint('Failed to load recently used: $e');
    }
  }

  Future<void> _saveRecentlyUsed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_recentKey, recentlyUsedNames.toList());
    } catch (e) {
      debugPrint('Failed to save recently used: $e');
    }
  }

  /// Get list of recently used emotes
  List<Emote> getRecentEmotes() {
    return recentlyUsedNames
        .where((name) => _emoteMap.containsKey(name))
        .map((name) => _emoteMap[name]!)
        .toList();
  }

  /// Search emotes by name (case-insensitive)
  List<Emote> searchEmotes(String query) {
    if (query.isEmpty) return emoteList.toList();

    final lowerQuery = query.toLowerCase();
    return emoteList
        .where((e) => e.name.toLowerCase().contains(lowerQuery))
        .toList();
  }

  /// Search Twitch emotes by name (case-insensitive)
  List<Emote> searchTwitchEmotes(String query) {
    if (query.isEmpty) return twitchEmoteList.toList();
    final lowerQuery = query.toLowerCase();
    return twitchEmoteList
        .where((e) => e.name.toLowerCase().contains(lowerQuery))
        .toList();
  }
}