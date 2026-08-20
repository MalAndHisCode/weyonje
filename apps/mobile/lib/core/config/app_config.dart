class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    this.googleMapsEnabled = false,
    this.fcmEnabled = false,
    this.environment = 'development',
  });

  factory AppConfig.fromEnvironment() => const AppConfig(
    apiBaseUrl: String.fromEnvironment('WEYONJE_API_BASE_URL'),
    googleMapsEnabled: bool.fromEnvironment('WEYONJE_GOOGLE_MAPS_ENABLED'),
    fcmEnabled: bool.fromEnvironment('WEYONJE_FCM_ENABLED'),
    environment: String.fromEnvironment(
      'WEYONJE_ENVIRONMENT',
      defaultValue: 'development',
    ),
  );

  final String apiBaseUrl;
  final bool googleMapsEnabled;
  final bool fcmEnabled;
  final String environment;

  String? validate() {
    final api = Uri.tryParse(apiBaseUrl);
    if (api == null ||
        !api.hasAuthority ||
        api.scheme != 'https' ||
        api.host.endsWith('.invalid')) {
      return 'The Weyonje API address is not configured securely.';
    }
    return null;
  }
}
