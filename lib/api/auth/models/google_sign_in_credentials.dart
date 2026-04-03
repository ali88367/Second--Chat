/// Google account data and OAuth tokens for sending to your backend (e.g. Node API).
class GoogleSignInCredentials {
  const GoogleSignInCredentials({
    required this.googleId,
    required this.idToken,
    this.accessToken,
    required this.email,
    this.displayName,
    this.photoUrl,
  });

  /// Stable Google user id (subject in the ID token).
  final String googleId;

  /// OpenID Connect ID token — verify on the server with Google's certs.
  final String idToken;

  /// OAuth2 access token for Google APIs (may be null if scopes were not granted).
  final String? accessToken;

  final String email;
  final String? displayName;
  final String? photoUrl;
}
