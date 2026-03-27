import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/models/session_tokens.dart';
import 'token_store.dart';

class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _kAccessToken = 'second_chat.access_token';
  static const _kRefreshToken = 'second_chat.refresh_token';
  static const _kAccessTokenExpiresAt = 'second_chat.access_token_expires_at';

  @override
  Future<SessionTokens?> read() async {
    // 1) Try secure storage first.
    final secureAccessToken = await _storage.read(key: _kAccessToken);
    final secureRefreshToken = await _storage.read(key: _kRefreshToken);
    if (secureAccessToken != null &&
        secureAccessToken.isNotEmpty &&
        secureRefreshToken != null &&
        secureRefreshToken.isNotEmpty) {
      final expiresAtRaw =
          await _storage.read(key: _kAccessTokenExpiresAt);
      final expiresAt = expiresAtRaw == null || expiresAtRaw.isEmpty
          ? null
          : DateTime.tryParse(expiresAtRaw);

      return SessionTokens(
        accessToken: secureAccessToken,
        refreshToken: secureRefreshToken,
        accessTokenExpiresAt: expiresAt,
      );
    }

    // 2) Fallback to SharedPreferences when secure storage is empty.
    // This allows the app to recover tokens and refresh them.
    final prefs = await SharedPreferences.getInstance();
    final prefsAccessToken = prefs.getString(_kAccessToken)?.trim();
    final prefsRefreshToken = prefs.getString(_kRefreshToken)?.trim();
    if (prefsAccessToken == null ||
        prefsAccessToken.isEmpty ||
        prefsRefreshToken == null ||
        prefsRefreshToken.isEmpty) {
      return null;
    }

    final expiresAtRaw = prefs.getString(_kAccessTokenExpiresAt);
    final expiresAt = expiresAtRaw == null || expiresAtRaw.isEmpty
        ? null
        : DateTime.tryParse(expiresAtRaw);

    return SessionTokens(
      accessToken: prefsAccessToken,
      refreshToken: prefsRefreshToken,
      accessTokenExpiresAt: expiresAt,
    );
  }

  @override
  Future<void> write(SessionTokens tokens) async {
    await _storage.write(key: _kAccessToken, value: tokens.accessToken);
    await _storage.write(key: _kRefreshToken, value: tokens.refreshToken);
    await _storage.write(
      key: _kAccessTokenExpiresAt,
      value: tokens.accessTokenExpiresAt?.toIso8601String() ?? '',
    );

    // Also mirror into SharedPreferences so other app parts can work even
    // if secure storage is not available/cleared.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccessToken, tokens.accessToken);
    await prefs.setString(_kRefreshToken, tokens.refreshToken);
    await prefs.setString(
      _kAccessTokenExpiresAt,
      tokens.accessTokenExpiresAt?.toIso8601String() ?? '',
    );
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _kAccessToken);
    await _storage.delete(key: _kRefreshToken);
    await _storage.delete(key: _kAccessTokenExpiresAt);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccessToken);
    await prefs.remove(_kRefreshToken);
    await prefs.remove(_kAccessTokenExpiresAt);
  }
}

