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

  /// OAuth 2.0 **Web** client id (Google Cloud Console). **Required on Android** for Google Sign-In.
  ///
  /// Order: `--dart-define=GOOGLE_SERVER_CLIENT_ID=...` / `dart_defines.json`, else [AppConstants.googleServerClientId].
  static String get googleServerClientId {
    const v = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID', defaultValue: '');
    if (v.trim().isNotEmpty) return v.trim();
    return AppConstants.googleServerClientId.trim();
  }

  /// iOS OAuth client id (`*.apps.googleusercontent.com`) if not using GoogleService-Info.plist.
  static String get googleIosClientId {
    const v = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID', defaultValue: '');
    if (v.trim().isNotEmpty) return v.trim();
    return AppConstants.googleIosClientId.trim();
  }
}
