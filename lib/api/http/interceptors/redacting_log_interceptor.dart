import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class RedactingLogInterceptor extends Interceptor {
  String _redact(String input) {
    // Best-effort redaction for common token fields.
    final patterns = <RegExp>[
      RegExp(r'(\"accessToken\"\\s*:\\s*\")([^\"]+)(\")', caseSensitive: false),
      RegExp(r'(\"refreshToken\"\\s*:\\s*\")([^\"]+)(\")', caseSensitive: false),
      RegExp(r'(\"idToken\"\\s*:\\s*\")([^\"]+)(\")', caseSensitive: false),
      RegExp(r'(\"access_token\"\\s*:\\s*\")([^\"]+)(\")', caseSensitive: false),
      RegExp(r'(\"refresh_token\"\\s*:\\s*\")([^\"]+)(\")', caseSensitive: false),
    ];
    var out = input;
    for (final p in patterns) {
      out = out.replaceAllMapped(p, (m) => '${m[1]}***${m[3]}');
    }
    return out;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      final headers = Map<String, dynamic>.from(options.headers);
      if (headers.containsKey('Authorization')) headers['Authorization'] = '***';
      debugPrint('HTTP ${options.method} ${options.uri}');
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      final status = err.response?.statusCode;
      final method = err.requestOptions.method;
      final uri = err.requestOptions.uri;
      debugPrint(
        'HTTP ERR $status $method $uri (${err.type}) ${err.message ?? ''}',
      );
      final data = err.response?.data;
      if (data != null) {
        final str = _redact(data.toString());
        final snippet = str.length > 800 ? '${str.substring(0, 800)}…' : str;
        debugPrint('HTTP ERR BODY: $snippet');
      }
    }
    handler.next(err);
  }
}
