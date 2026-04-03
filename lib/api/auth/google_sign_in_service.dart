import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config/api_config.dart';
import 'models/google_sign_in_credentials.dart';

/// Wraps [GoogleSignIn] (v7+) to obtain ID token, access token, and account id for a backend.
///
/// Does **not** use Firebase Auth — tokens are for your own API.
class GoogleSignInService {
  GoogleSignInService._();
  static final GoogleSignInService instance = GoogleSignInService._();

  bool _initialized = false;

  Future<void> ensureInitialized() async {
    if (_initialized) return;

    final serverId = ApiConfig.googleServerClientId;
    final iosClientId = ApiConfig.googleIosClientId;

    String? clientId;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      if (iosClientId.isNotEmpty) {
        clientId = iosClientId;
      }
    }

    // Android: plugin requires a non-null serverClientId (Web OAuth client id).
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      if (serverId.isEmpty) {
        throw StateError(
          'Set your Google **Web** OAuth client ID:\n'
          '• Edit `AppConstants.googleServerClientId` in '
          'lib/core/constants/constants.dart, or\n'
          '• Run with --dart-define=GOOGLE_SERVER_CLIENT_ID=xxx.apps.googleusercontent.com '
          '(or --dart-define-from-file=dart_defines.json).',
        );
      }
    }

    await GoogleSignIn.instance.initialize(
      clientId: clientId,
      serverClientId: serverId.isEmpty ? null : serverId,
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
        'Missing Google ID token. Ensure `AppConstants.googleServerClientId` '
        '(or GOOGLE_SERVER_CLIENT_ID) is your Web OAuth client id.',
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
    } catch (e) {
      if (kDebugMode) {
        debugPrint('GoogleSignIn: optional access token not obtained: $e');
      }
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
