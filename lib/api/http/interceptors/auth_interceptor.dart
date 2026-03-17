import 'dart:async';

import 'package:dio/dio.dart';

import '../../auth/auth_api.dart';
import '../../auth/models/session_tokens.dart';
import '../../storage/token_store.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required TokenStore tokenStore,
    required Dio dio,
  })  : _tokenStore = tokenStore,
        _dio = dio,
        _authApi = AuthApi(dio);

  final TokenStore _tokenStore;
  final Dio _dio;
  final AuthApi _authApi;

  Future<SessionTokens>? _refreshInFlight;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final tokens = await _tokenStore.read();
    if (tokens != null && tokens.accessToken.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
    }
    handler.next(options);
  }

  bool _shouldAttemptRefresh(DioException err) {
    final status = err.response?.statusCode;
    if (status != 401) return false;
    final path = err.requestOptions.path;
    if (path.contains('/api/v1/auth/refresh')) return false;
    return err.requestOptions.extra['__retry'] != true;
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (!_shouldAttemptRefresh(err)) {
      handler.next(err);
      return;
    }

    final current = await _tokenStore.read();
    if (current == null) {
      handler.next(err);
      return;
    }

    try {
      _refreshInFlight ??= _authApi.refresh(current.refreshToken).whenComplete(() {
        _refreshInFlight = null;
      });

      final newTokens = await _refreshInFlight!;
      await _tokenStore.write(newTokens);

      final requestOptions = err.requestOptions;
      requestOptions.extra['__retry'] = true;
      requestOptions.headers['Authorization'] = 'Bearer ${newTokens.accessToken}';

      final response = await _dio.fetch<dynamic>(requestOptions);
      handler.resolve(response);
    } on DioException catch (refreshErr) {
      _refreshInFlight = null;
      final status = refreshErr.response?.statusCode;
      if (status == 401) {
        await _tokenStore.clear();
      }
      handler.next(err);
    } catch (_) {
      _refreshInFlight = null;
      handler.next(err);
    }
  }
}
