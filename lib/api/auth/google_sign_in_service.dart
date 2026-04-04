import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config/api_config.dart';
import 'models/google_sign_in_credentials.dart';

/// Wraps [GoogleSignIn] (v7+) to obtain ID token, access token, and account id for a backend.
///
/// Does **not** use Firebase Auth — tokens are for your own API.
///
/// Initialization uses only [ApiConfig.googleServerClientId] (Web OAuth client id) — no per-platform `clientId`.
class GoogleSignInService {
  GoogleSignInService._();
  static final GoogleSignInService instance = GoogleSignInService._();

  bool _initialized = false;

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

    await GoogleSignIn.instance.initialize(
      serverClientId: serverId,
    );
    _initialized = true;
  }

  /// Interactive Google sign-in; returns credentials including [GoogleSignInCredentials.idToken].
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
      const scopes = <String>[
        'https://www.googleapis.com/auth/userinfo.email',
        'https://www.googleapis.com/auth/userinfo.profile',
      ];
      GoogleSignInClientAuthorization? authz =
          await account.authorizationClient.authorizationForScopes(scopes);
      authz ??= await account.authorizationClient.authorizeScopes(scopes);
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
