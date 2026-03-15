import 'package:dio/dio.dart';

import '../http/api_json.dart';
import 'models/session_tokens.dart';

class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<SessionTokens> login({
    required String email,
    required String password,
  }) async {
    final res = await _dio.post<dynamic>(
      '/api/v1/auth/login',
      data: {'email': email, 'password': password},
    );
    return _parseTokens(res.data);
  }

  Future<SessionTokens> register({
    required String email,
    required String password,
    required String username,
  }) async {
    final res = await _dio.post<dynamic>(
      '/api/v1/auth/register',
      data: {'email': email, 'password': password, 'username': username},
    );
    return _parseTokens(res.data);
  }

  Future<SessionTokens> refresh(String refreshToken) async {
    final res = await _dio.post<dynamic>(
      '/api/v1/auth/refresh',
      data: {'refreshToken': refreshToken},
    );
    return _parseTokens(res.data, fallbackRefreshToken: refreshToken);
  }

  Future<void> logout() async {
    await _dio.post<dynamic>('/api/v1/auth/logout');
  }

  Future<Map<String, dynamic>> me() async {
    final res = await _dio.get<dynamic>('/api/v1/users/me');
    final json = res.data;
    if (json is Map<String, dynamic>) {
      final data = json['data'];
      if (data is Map<String, dynamic>) return data;
      return json;
    }
    return <String, dynamic>{};
  }

  SessionTokens _parseTokens(
    dynamic json, {
    String? fallbackRefreshToken,
  }) {
    final accessToken = extractString(json, const [
      'accessToken',
      'access_token',
      'token',
    ]);
    final refreshToken = extractString(json, const [
      'refreshToken',
      'refresh_token',
    ]);

    if (accessToken == null || accessToken.isEmpty) {
      throw StateError('Missing access token in response');
    }

    final resolvedRefresh = (refreshToken == null || refreshToken.isEmpty)
        ? (fallbackRefreshToken ?? '')
        : refreshToken;

    if (resolvedRefresh.isEmpty) {
      throw StateError('Missing refresh token in response');
    }

    DateTime? expiresAt;
    final expiresInRaw = extractJson(json, const ['expiresIn', 'expires_in']);
    if (expiresInRaw is num) {
      expiresAt = DateTime.now().toUtc().add(Duration(seconds: expiresInRaw.toInt()));
    }

    final expiresAtRaw = extractString(json, const ['expiresAt', 'expires_at']);
    expiresAt ??= expiresAtRaw == null ? null : DateTime.tryParse(expiresAtRaw);

    return SessionTokens(
      accessToken: accessToken,
      refreshToken: resolvedRefresh,
      accessTokenExpiresAt: expiresAt,
    );
  }
}

