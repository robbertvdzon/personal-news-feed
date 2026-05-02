class AppConfig {
  // Override at build/run time with: --dart-define=API_BASE_URL=http://...
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://pnf.vdzon.com',
  );

  static const String wsBaseUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'wss://pnf.vdzon.com',
  );
}
