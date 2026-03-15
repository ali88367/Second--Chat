class SessionTokens {
  const SessionTokens({
    required this.accessToken,
    required this.refreshToken,
    this.accessTokenExpiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime? accessTokenExpiresAt;

  SessionTokens copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? accessTokenExpiresAt,
  }) {
    return SessionTokens(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      accessTokenExpiresAt: accessTokenExpiresAt ?? this.accessTokenExpiresAt,
    );
  }
}

