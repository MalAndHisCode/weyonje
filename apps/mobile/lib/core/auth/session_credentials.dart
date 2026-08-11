class SessionCredentials {
  const SessionCredentials({
    required this.accessToken,
    this.refreshToken,
    this.idToken,
    this.accessTokenExpiration,
  });

  final String accessToken;
  final String? refreshToken;
  final String? idToken;
  final DateTime? accessTokenExpiration;
}
