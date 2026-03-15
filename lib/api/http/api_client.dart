import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../storage/token_store.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/redacting_log_interceptor.dart';

class ApiClient {
  ApiClient({
    required TokenStore tokenStore,
    Dio? dio,
    String? baseUrl,
  }) : dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? ApiConfig.baseUrl,
                connectTimeout: ApiConfig.connectTimeout,
                receiveTimeout: ApiConfig.receiveTimeout,
                headers: const {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
              ),
            ) {
    this.dio.interceptors.addAll([
      AuthInterceptor(
        tokenStore: tokenStore,
        dio: this.dio,
      ),
      RedactingLogInterceptor(),
    ]);
  }

  final Dio dio;
}

