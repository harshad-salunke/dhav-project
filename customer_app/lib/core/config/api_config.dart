class ApiConfig {
  /// Base URL for the DHAV FastAPI backend.
  /// Override at build time: --dart-define=API_BASE_URL=https://your-backend.com
  /// Default points to Android emulator's localhost (10.0.2.2) on port 8000.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    // defaultValue: 'http://10.0.2.2:8000'
    defaultValue: 'http://10.221.74.78:8000',
  );

  /// WebSocket base URL (ws:// or wss://)
  static String get wsBaseUrl => baseUrl
      .replaceFirst('http://', 'ws://')
      .replaceFirst('https://', 'wss://');
}
