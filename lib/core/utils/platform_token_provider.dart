import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class PlatformTokenProvider {
  static const platformTokensKey = 'second_chat.platform_tokens';
  static const accessTokenKey = 'accessToken';
  static const refreshTokenKey = 'refreshToken';
  static const googleOAuthAccessTokenKey = 'second_chat.google_oauth_access_token';

  /// Google Sign-In OAuth **access** token (`ya29…`) set once after login via [AuthController.loginWithGoogle].
  /// Session checks do not re-prompt Google; read with [GoogleSignInService.readStoredGoogleAccessToken].
  Future<String?> getGoogleOAuthAccessToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final t = prefs.getString(googleOAuthAccessTokenKey)?.trim();
      return (t == null || t.isEmpty) ? null : t;
    } catch (_) {
      return null;
    }
  }

  Future<void> setGoogleOAuthAccessToken(String? token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = token?.trim();
      if (v == null || v.isEmpty) {
        await prefs.remove(googleOAuthAccessTokenKey);
      } else {
        await prefs.setString(googleOAuthAccessTokenKey, v);
      }
    } catch (_) {}
  }

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

  /// Updates platform tokens inside SharedPreferences `second_chat.platform_tokens`.
  ///
  /// Backend-refresh result tokens are mirrored here so subsequent socket
  /// connections authenticate successfully for that platform.
  Future<void> setPlatformTokens({
    required String platform,
    required String accessToken,
    required String refreshToken,
  }) async {
    final p = platform.toLowerCase().trim();
    if (p.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(platformTokensKey);

    Map<String, dynamic> map;
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        map = decoded is Map<String, dynamic>
            ? decoded
            : Map<String, dynamic>.from(decoded as Map);
      } catch (_) {
        map = <String, dynamic>{};
      }
    } else {
      map = <String, dynamic>{};
    }

    map[p] = <String, dynamic>{
      accessTokenKey: accessToken,
      refreshTokenKey: refreshToken,
    };

    await prefs.setString(platformTokensKey, jsonEncode(map));
  }

  Future<Map<String, dynamic>?> _readPlatformTokenMap(String platform) async {
    try {
      final key = platform.toLowerCase().trim();
      if (key.isEmpty) return null;
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(platformTokensKey);
      if (raw == null || raw.trim().isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;

      final map = decoded.cast<String, dynamic>();
      final entry = map[key];
      if (entry is Map) {
        return entry.cast<String, dynamic>();
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
