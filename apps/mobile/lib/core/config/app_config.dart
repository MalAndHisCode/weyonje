class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.keycloakIssuer,
    required this.keycloakClientId,
    required this.redirectUri,
  });

  factory AppConfig.fromEnvironment() => const AppConfig(
    apiBaseUrl: String.fromEnvironment('WEYONJE_API_BASE_URL'),
    keycloakIssuer: String.fromEnvironment('WEYONJE_KEYCLOAK_ISSUER'),
    keycloakClientId: String.fromEnvironment('WEYONJE_KEYCLOAK_CLIENT_ID'),
    redirectUri: String.fromEnvironment('WEYONJE_AUTH_REDIRECT_URI'),
  );

  final String apiBaseUrl;
  final String keycloakIssuer;
  final String keycloakClientId;
  final String redirectUri;

  String? validate() {
    final api = Uri.tryParse(apiBaseUrl);
    final issuer = Uri.tryParse(keycloakIssuer);
    final redirect = Uri.tryParse(redirectUri);
    if (api == null || !api.hasAuthority || api.scheme != 'https') {
      return 'The Weyonje API address is not configured securely.';
    }
    if (issuer == null || !issuer.hasAuthority || issuer.scheme != 'https') {
      return 'The Weyonje identity service is not configured securely.';
    }
    if (keycloakClientId.trim().isEmpty) {
      return 'The Weyonje mobile identity client is not configured.';
    }
    if (redirect == null ||
        redirect.scheme.isEmpty ||
        redirect.scheme == 'http' ||
        redirect.scheme == 'https') {
      return 'The secure sign-in return address is not configured.';
    }
    return null;
  }

  String get discoveryUrl =>
      '${keycloakIssuer.replaceAll(RegExp(r'/$'), '')}/.well-known/openid-configuration';
}
