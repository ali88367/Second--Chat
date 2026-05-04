import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/utils/platform_token_provider.dart';
import '../config/api_config.dart';
import 'models/google_sign_in_credentials.dart';

/// Wraps [GoogleSignIn] (v7+) to obtain ID token, access token, and account id for a backend.
///
/// Does **not** use Firebase Auth — tokens are for your own API.
///
/// **Google account UI** runs only from [signInAndFetchCredentials] (login screen). The OAuth
/// access token is persisted via [PlatformTokenProvider.setGoogleOAuthAccessToken]; session
/// checks must **not** call the Google SDK again (avoids repeated account prompts).
///
/// Initialization uses [ApiConfig.googleServerClientId] (web client for ID tokens) and, on iOS,
/// [ApiConfig.googleIosClientId] when set (matches `CLIENT_ID` in `GoogleService-Info.plist`).
class GoogleSignInService {
  GoogleSignInService._();
  static final GoogleSignInService instance = GoogleSignInService._();

  bool _initialized = false;

  /// OAuth scopes for profile/email access token (must match [signInAndFetchCredentials]).
  static const List<String> oauthScopes = <String>[
    'https://www.googleapis.com/auth/userinfo.email',
    'https://www.googleapis.com/auth/userinfo.profile',
  ];

  Future<void> ensureInitialized() async {
    if (_initialized) return;

    final serverId = ApiConfig.googleServerClientId.trim();
    if (serverId.isEmpty) {
      throw StateError(
        'Set `AppConstants.googleServerClientId` in lib/core/constants/constants.dart '
        'to your Web OAuth client id (…apps.googleusercontent.com), or pass '
        '--dart-define=GOOGLE_SERVER_CLIENT_ID=...',
      );
    }

    final iosClientId = ApiConfig.googleIosClientId.trim();
    await GoogleSignIn.instance.initialize(
      serverClientId: serverId,
      clientId:
          !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS && iosClientId.isNotEmpty
              ? iosClientId
              : null,
    );
    _initialized = true;
  }

  /// Token saved at Google login — **no** Google SDK calls (safe during session checks).
  Future<String?> readStoredGoogleAccessToken() async {
    return PlatformTokenProvider().getGoogleOAuthAccessToken();
  }

  /// Interactive Google sign-in; returns credentials including [GoogleSignInCredentials.idToken].
  /// Persists OAuth access token to SharedPreferences via [loginWithGoogle] in [AuthController].
  Future<GoogleSignInCredentials> signInAndFetchCredentials() async {
    await ensureInitialized();

    final GoogleSignInAccount account = await GoogleSignIn.instance.authenticate(
      scopeHint: const ['email', 'profile', 'openid'],
    );

    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError(
        'Missing Google ID token. Check `AppConstants.googleServerClientId` '
        '(Web OAuth client from the same Firebase project as google-services.json).',
      );
    }

    String? accessToken;
    try {
      GoogleSignInClientAuthorization? authz =
          await account.authorizationClient.authorizationForScopes(oauthScopes);
      authz ??= await account.authorizationClient.authorizeScopes(oauthScopes);
      accessToken = authz.accessToken;
    } catch (_) {
      // Optional; backend login uses idToken.
    }

    if (kDebugMode && accessToken != null) {
      debugPrint('accessToken: $accessToken');
    }

    return GoogleSignInCredentials(
      googleId: account.id,
      idToken: idToken,
      accessToken: accessToken,
      email: account.email,
      displayName: account.displayName,
      photoUrl: account.photoUrl,
    );
  }

  Future<void> signOut() async {
    if (!_initialized) return;
    try {
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      if (kDebugMode) debugPrint('GoogleSignIn signOut: $e');
    }
  }
}
