import 'package:dio/dio.dart';

import '../http/api_json.dart';
import 'jwt_utils.dart';
import 'models/session_tokens.dart';

class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  /// POST body for `/api/v1/auth/google/mobile` must match the backend
  /// (`oauth.controller.ts`): **`idToken`** = OpenID JWT only (`eyJ...`), optional
  /// **`accessToken`** = Google OAuth access token (`ya29...`, not verified for login).
  /// Do **not** send `token` / `credential` with the access token as the JWT field.
  Future<SessionTokens> loginWithGoogle({
    required String idToken,
    String? accessToken,
  }) async {
    final trimmedId = idToken.trim();
    if (!trimmedId.startsWith('eyJ')) {
      throw ArgumentError(
        'idToken must be the Google ID token JWT (OpenID), typically starting with '
        '"eyJ". Do not send the OAuth access token (ya29...) as idToken.',
      );
    }

    final trimmedAccess = accessToken?.trim();
    final data = <String, dynamic>{
      'idToken': trimmedId,
      'accessToken':
          (trimmedAccess != null && trimmedAccess.isNotEmpty)
              ? trimmedAccess
              : null,
      'refreshToken': null,
    };

    final res = await _dio.post<dynamic>(
      '/api/v1/auth/google/mobile',
      data: data,
    );
    return _parseTokens(res.data);
  }

  /// Apple Sign-In exchange endpoint (iOS mobile).
  /// Matches backend contract:
  /// `{ identityToken, fullName?, email? }`.
  Future<SessionTokens> loginWithApple({
    required String identityToken,
    String? fullName,
    String? email,
  }) async {
    final trimmedId = identityToken.trim();
    if (!trimmedId.startsWith('eyJ')) {
      throw ArgumentError(
        'identityToken must be the Apple identity token JWT (typically starts with "eyJ").',
      );
    }
    final trimmedFullName = fullName?.trim();
    final trimmedEmail = email?.trim();
    final res = await _dio.post<dynamic>(
      '/api/v1/auth/apple/mobile',
      data: <String, dynamic>{
        'identityToken': trimmedId,
        'fullName':
            (trimmedFullName != null && trimmedFullName.isNotEmpty)
                ? trimmedFullName
                : null,
        'email':
            (trimmedEmail != null && trimmedEmail.isNotEmpty)
                ? trimmedEmail
                : null,
      },
    );
    return _parseTokens(res.data);
  }

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

  /// Pass [accessToken] as `Authorization: Bearer` (required by backend for logout).
  Future<Response<dynamic>> logout({String? accessToken}) async {
    final trimmed = accessToken?.trim();
    final opts =
        trimmed != null && trimmed.isNotEmpty
            ? Options(headers: {'Authorization': 'Bearer $trimmed'})
            : Options();
    return _dio.post<dynamic>('/api/v1/auth/logout', options: opts);
  }

  Future<Map<String, dynamic>> me() async {
    final res = await _dio.get<dynamic>('/api/v1/users/me');
    final json = res.data;
    if (json is Map) {
      final root = Map<String, dynamic>.from(json);
      if (root['success'] == false) {
        final msg = root['message']?.toString().trim();
        throw StateError(
          (msg != null && msg.isNotEmpty)
              ? msg
              : 'Failed to fetch user profile',
        );
      }
      final data = root['data'];
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return root;
    }
    return <String, dynamic>{};
  }

  SessionTokens _parseTokens(
    dynamic json, {
    String? fallbackRefreshToken,
  }) {
    if (json is Map) {
      final m = Map<String, dynamic>.from(json);
      if (m['success'] == false) {
        final msg = m['message']?.toString().trim();
        throw StateError(
          (msg != null && msg.isNotEmpty) ? msg : 'Authentication failed',
        );
      }
    }

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
      expiresAt = DateTime.now().toUtc().add(
        Duration(seconds: expiresInRaw.toInt()),
      );
    }

    final expiresAtRaw = extractString(json, const ['expiresAt', 'expires_at']);
    expiresAt ??= expiresAtRaw == null ? null : DateTime.tryParse(expiresAtRaw);

    expiresAt ??= parseJwtAccessTokenExpiryUtc(accessToken);

    return SessionTokens(
      accessToken: accessToken,
      refreshToken: resolvedRefresh,
      accessTokenExpiresAt: expiresAt,
    );
  }
}

