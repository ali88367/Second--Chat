enum OAuthProvider {
  twitch('twitch'),
  kick('kick'),
  youtube('google');

  const OAuthProvider(this.backendKey);

  final String backendKey;
}

