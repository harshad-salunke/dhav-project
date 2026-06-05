/// Backend connection config.
///
/// `10.0.2.2` is the Android emulator's alias for the host machine's
/// `localhost`. Change this for physical-device / production builds.
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    // defaultValue: 'http://10.0.2.2:8000',  // Android emulator (local)
    defaultValue: 'https://dhav-backend.onrender.com',
  );

  static const String wsBaseUrl = String.fromEnvironment(
    'WS_BASE_URL',
    // defaultValue: 'ws://10.0.2.2:8000',  // Android emulator (local)
    defaultValue: 'https://dhav-backend.onrender.com',
  );

  static const Duration requestTimeout = Duration(seconds: 15);
}
