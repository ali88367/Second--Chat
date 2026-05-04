import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'models/apple_sign_in_credentials.dart';

class AppleSignInService {
  AppleSignInService._();
  static final AppleSignInService instance = AppleSignInService._();

  static const _charset =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';

  String _randomNonce([int length = 32]) {
    final random = Random.secure();
    return List<String>.generate(
      length,
      (_) => _charset[random.nextInt(_charset.length)],
    ).join();
  }

  String _sha256(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  Future<AppleSignInCredentials> signInAndFetchCredentials() async {
    if (!Platform.isIOS) {
      throw StateError('Apple Sign-In is currently enabled only on iOS.');
    }
    final available = await SignInWithApple.isAvailable();
    if (!available) {
      throw StateError('Apple Sign-In is not available on this device.');
    }

    final rawNonce = _randomNonce();
    final nonceHash = _sha256(rawNonce);

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: const [AppleIDAuthorizationScopes.email],
      nonce: nonceHash,
    );

    final idToken = appleCredential.identityToken?.trim() ?? '';
    final authCode = appleCredential.authorizationCode.trim();
    if (idToken.isEmpty || authCode.isEmpty) {
      throw StateError('Apple sign-in did not return required tokens.');
    }

    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: idToken,
      rawNonce: rawNonce,
      accessToken: authCode,
    );
    await FirebaseAuth.instance.signInWithCredential(oauthCredential);

    return AppleSignInCredentials(
      idToken: idToken,
      authorizationCode: authCode,
      rawNonce: rawNonce,
      email: appleCredential.email,
      givenName: appleCredential.givenName,
      familyName: appleCredential.familyName,
    );
  }

  Future<void> signOutFirebaseSession() async {
    await FirebaseAuth.instance.signOut();
  }
}
