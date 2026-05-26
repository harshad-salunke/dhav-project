class ApiConfig {
  // Dev: Flutter Web runs on localhost; backend on :8000
  // Override with --dart-define=API_BASE_URL=https://your-prod-url
  static const String baseUrl = String.fromEnvironment('API_BASE_URL',
      defaultValue: 'https://dhav-backend-production.up.railway.app');
}
