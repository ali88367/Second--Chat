/// Constants
/// 
/// Centralized constants for the entire application.
/// Contains app-wide string constants, numeric values, and configuration.
class AppConstants {
  AppConstants._(); // Private constructor to prevent instantiation

  // App Information
  static const String appName = 'Second Chat';
  static const String appVersion = '1.0.0';

  // API Constants
  // Backend base URL (overridable at build/run time via `--dart-define=API_BASE_URL=...`).
  static const String baseUrl = 'https://api.secondchat.co';

  /// **Web application** OAuth client ID — must be from the **same** Firebase/Google project as
  /// `android/app/google-services.json` (see `oauth_client` with `client_type` 3 there).
  /// A client ID from a different project (different numeric prefix) breaks Android Google Sign-In.
  ///
  /// The ID token’s JWT `aud` must also be listed as an allowed audience on your **backend**
  /// (`INVALID_TOKEN` / “jwt audience invalid” means the server expects different client IDs than
  /// this one — fix the server config, or align Firebase with the backend’s Google Cloud project).
  /// Override per build with `--dart-define=GOOGLE_SERVER_CLIENT_ID=...` or `dart_defines.json`.
  static const String googleServerClientId =
      '209792077701-4ohf0aotq67a9orph2mhfal4rsnqvcf2.apps.googleusercontent.com';

  /// iOS OAuth client ID (`CLIENT_ID` in `GoogleService-Info.plist`). Same Firebase project as
  /// [googleServerClientId]. Override with `--dart-define=GOOGLE_IOS_CLIENT_ID=...`.
  static const String googleIosClientId =
      '209792077701-uqmqji55nnm6dvmsi7pekcqh30e6uogp.apps.googleusercontent.com';
  static const int connectionTimeout = 30000; // milliseconds
  static const int receiveTimeout = 30000; // milliseconds

  // Storage Keys
  static const String keyIsFirstLaunch = 'is_first_launch';
  static const String keyAuthToken = 'auth_token';
  static const String keyUserId = 'user_id';
  static const String keyUserData = 'user_data';
  static const String keyThemeMode = 'theme_mode';
  static const String keyLanguage = 'language';
  static const String keyFontSize = 'font_size';

  /// After login, user sees [NotficationScreens] → intro 3–5 until home; then set `true`.
  static const String keyIntroOnboardingComplete = 'second_chat.intro_onboarding_complete';

  // Animation Durations
  static const Duration animationDurationShort = Duration(milliseconds: 200);
  static const Duration animationDurationMedium = Duration(milliseconds: 300);
  static const Duration animationDurationLong = Duration(milliseconds: 500);

  // Debounce Durations
  static const Duration debounceDuration = Duration(milliseconds: 500);

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Validation
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 128;
  static const int minUsernameLength = 3;
  static const int maxUsernameLength = 30;
  static const int maxEmailLength = 255;
  static const int maxPhoneLength = 15;

  // Date Formats
  static const String dateFormat = 'yyyy-MM-dd';
  static const String timeFormat = 'HH:mm';
  static const String dateTimeFormat = 'yyyy-MM-dd HH:mm';
  static const String displayDateFormat = 'MMM dd, yyyy';
  static const String displayTimeFormat = 'hh:mm a';
}
