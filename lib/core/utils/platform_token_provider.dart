import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class PlatformTokenProvider {
  static const platformTokensKey = 'second_chat.platform_tokens';
  static const accessTokenKey = 'accessToken';
  static const refreshTokenKey = 'refreshToken';

  /// Returns platforms that have a non-empty accessToken in `second_chat.platform_tokens`.
  /// Example: ["twitch","kick","youtube"].
  Future<List<String>> getConnectedPlatforms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(platformTokensKey);
      if (raw == null || raw.trim().isEmpty) return const [];

      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const [];
      final map = decoded.cast<String, dynamic>();

      final out = <String>[];
      for (final entry in map.entries) {
        final key = entry.key.toString().toLowerCase().trim();
        if (key.isEmpty) continue;
        final value = entry.value;
        if (value is! Map) continue;
        final token = (value[accessTokenKey] ?? '').toString().trim();
        if (token.isNotEmpty) out.add(key);
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  Future<String?> getAccessToken(String platform) async {
    final tokens = await _readPlatformTokenMap(platform);
    final token = (tokens?[accessTokenKey] ?? '').toString().trim();
    return token.isEmpty ? null : token;
  }

  Future<String?> getRefreshToken(String platform) async {
    final tokens = await _readPlatformTokenMap(platform);
    final token = (tokens?[refreshTokenKey] ?? '').toString().trim();
    return token.isEmpty ? null : token;
  }

  Future<Map<String, dynamic>?> _readPlatformTokenMap(String platform) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(platformTokensKey);
      if (raw == null || raw.trim().isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;

      final map = decoded.cast<String, dynamic>();
      final entry = map[platform];
      if (entry is Map) {
        return entry.cast<String, dynamic>();
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

