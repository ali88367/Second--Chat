import '../../core/constants/constants.dart';

class ApiConfig {
  ApiConfig._();

  // Prefer `AppConstants.baseUrl`; allow compile-time override via `--dart-define`.
  // Use a getter (not `const`) so it reflects changes immediately during dev/hot reload.
  static String get baseUrl {
    const override = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (override.trim().isNotEmpty) return override.trim();
    return AppConstants.baseUrl;
  }

  static const Duration connectTimeout = Duration(
    milliseconds: AppConstants.connectionTimeout,
  );

  static const Duration receiveTimeout = Duration(
    milliseconds: AppConstants.receiveTimeout,
  );

  static String get oauthRedirectUri {
    const override =
        String.fromEnvironment('OAUTH_REDIRECT_URI', defaultValue: '');
    if (override.trim().isNotEmpty) return override.trim();
    return 'secondchat://auth/callback';
  }
}
