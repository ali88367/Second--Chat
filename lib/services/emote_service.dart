import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
  static const String _recentKey = '7tv_recently_used';
  static const String _apiUrl = 'https://7tv.io/v3/emote-sets/global';
  static const int _maxRecentEmotes = 24;

  // Reactive state
  final RxMap<String, Emote> _emoteMap = <String, Emote>{}.obs;
  final RxList<Emote> emoteList = <Emote>[].obs;
  final RxBool isLoading = true.obs;
  final RxBool hasError = false.obs;
  final RxString errorMessage = ''.obs;
  final RxList<String> recentlyUsedNames = <String>[].obs;

  /// Map of emote name -> emote URL for quick lookup during parsing
  Map<String, String> get emoteUrlMap =>
      _emoteMap.map((key, value) => MapEntry(key, value.url));

  /// Get emote by name (case-sensitive)
  Emote? getEmote(String name) => _emoteMap[name];

  @override
  void onInit() {
    super.onInit();
    _initializeEmotes();
  }

  /// Initialize emotes: load from cache, then fetch fresh data
  Future<void> _initializeEmotes() async {
    isLoading.value = true;
    hasError.value = false;

    // Load from cache first for instant display
    await _loadFromCache();
    await _loadRecentlyUsed();

    // Fetch fresh data from API
    await fetchEmotes();
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

  void _handleError(String message) {
    debugPrint('EmoteService Error: $message');
    if (_emoteMap.isEmpty) {
      hasError.value = true;
      errorMessage.value = message;
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
}