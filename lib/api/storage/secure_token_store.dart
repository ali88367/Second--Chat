import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
    final accessToken = await _storage.read(key: _kAccessToken);
    final refreshToken = await _storage.read(key: _kRefreshToken);
    if (accessToken == null || accessToken.isEmpty) return null;
    if (refreshToken == null || refreshToken.isEmpty) return null;

    final expiresAtRaw = await _storage.read(key: _kAccessTokenExpiresAt);
    final expiresAt = expiresAtRaw == null || expiresAtRaw.isEmpty
        ? null
        : DateTime.tryParse(expiresAtRaw);

    return SessionTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
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
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _kAccessToken);
    await _storage.delete(key: _kRefreshToken);
    await _storage.delete(key: _kAccessTokenExpiresAt);
  }
}

