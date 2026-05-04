class AppleSignInCredentials {
  const AppleSignInCredentials({
    required this.idToken,
    required this.authorizationCode,
    required this.rawNonce,
    this.email,
    this.givenName,
    this.familyName,
  });

  final String idToken;
  final String authorizationCode;
  final String rawNonce;
  final String? email;
  final String? givenName;
  final String? familyName;
}
