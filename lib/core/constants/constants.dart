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
  static const String baseUrl = 'https://cafe7bygasco.com';

  /// Google Cloud → APIs & Services → Credentials → **OAuth 2.0 Client ID** of type **Web application**.
  /// Paste the full id (ends with `.apps.googleusercontent.com`). Android **requires** this.
  /// Override per build with `--dart-define=GOOGLE_SERVER_CLIENT_ID=...` or `dart_defines.json`.
  static const String googleServerClientId = '688446882450-32ad24bgrb04bjd4sfpijrce67o68i38.apps.googleusercontent.com';

  /// iOS-only OAuth client ID if you do not use `--dart-define=GOOGLE_IOS_CLIENT_ID`.
  static const String googleIosClientId = '';
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
