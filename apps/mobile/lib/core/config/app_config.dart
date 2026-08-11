class AppConfig {
  const AppConfig({required this.apiBaseUrl});

  factory AppConfig.fromEnvironment() => const AppConfig(
    apiBaseUrl: String.fromEnvironment('WEYONJE_API_BASE_URL'),
  );

  final String apiBaseUrl;

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
