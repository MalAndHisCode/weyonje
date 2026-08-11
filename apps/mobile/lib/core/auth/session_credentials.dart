class SessionCredentials {
  const SessionCredentials({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
    required this.refreshTokenExpiresAt,
  });

  factory SessionCredentials.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid stored session.');
    }
    final accessToken = value['accessToken'];
    final refreshToken = value['refreshToken'];
    final accessExpiry = DateTime.tryParse('${value['accessTokenExpiresAt']}');
    final refreshExpiry = DateTime.tryParse(
      '${value['refreshTokenExpiresAt']}',
    );
    if (accessToken is! String ||
        accessToken.isEmpty ||
        accessToken.length > 8192 ||
        refreshToken is! String ||
        refreshToken.isEmpty ||
        refreshToken.length > 512 ||
        accessExpiry == null ||
        refreshExpiry == null) {
      throw const FormatException('Invalid stored session.');
    }
    return SessionCredentials(
      accessToken: accessToken,
      refreshToken: refreshToken,
      accessTokenExpiresAt: accessExpiry.toUtc(),
      refreshTokenExpiresAt: refreshExpiry.toUtc(),
    );
  }

  final String accessToken;
  final String refreshToken;
  final DateTime accessTokenExpiresAt;
  final DateTime refreshTokenExpiresAt;

  Map<String, Object> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'accessTokenExpiresAt': accessTokenExpiresAt.toIso8601String(),
    'refreshTokenExpiresAt': refreshTokenExpiresAt.toIso8601String(),
  };
}
