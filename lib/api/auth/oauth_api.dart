import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../http/api_json.dart';
import 'oauth_provider.dart';

class OAuthApi {
  OAuthApi(this._dio);

  final Dio _dio;

  Future<Uri> getAuthUrl({
    required OAuthProvider provider,
    String? redirectUri,
    bool link = false,
  }) async {
    final path = link
        ? '/api/v1/auth/${provider.backendKey}/link'
        : '/api/v1/auth/${provider.backendKey}/url';

    // Use the provided redirectUri if supplied; otherwise fall back to config.

    final res = await _dio.get<dynamic>(
      path,
      queryParameters: {
        'redirectUri': redirectUri ?? ApiConfig.oauthRedirectUri,
      },
    );

    final authUrl = extractString(res.data, const [
      'url',
      'authUrl',
      'authorizationUrl',
      'authorizeUrl',
    ]);

    if (authUrl == null || authUrl.isEmpty) {
      throw StateError('Missing OAuth URL in response');
    }

    return Uri.parse(authUrl);
  }

  Future<dynamic> exchangeCallback({
    required OAuthProvider provider,
    required String code,
    String? state,
  }) async {
    final res = await _dio.get<dynamic>(
      '/api/v1/auth/${provider.backendKey}/callback',
      queryParameters: {
        'code': code,
        if (state != null && state.isNotEmpty) 'state': state,
      },
    );
    return res.data;
  }
}

