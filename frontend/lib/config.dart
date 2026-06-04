/// OmniCare configuration.
///
/// For physical device testing, run with:
///   flutter run --dart-define=BASE_URL=http://192.168.x.x:8000
///
/// The app auto-detects the host from --dart-define so there's
/// no settings screen needed — just pass it at launch time.
class Config {
  Config._();

  static const String baseUrlString = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://omnicare-backend-713636545861.us-central1.run.app',
  );

  static String get baseUrl => baseUrlString;

  /// Request timeout — Gemini can be slow under load.
  static const Duration requestTimeout = Duration(seconds: 45);
}
