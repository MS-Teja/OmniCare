/// OmniCare configuration.
///
/// For physical device testing, run with:
///   flutter run --dart-define=API_HOST=192.168.x.x
///
/// The app auto-detects the host from --dart-define so there's
/// no settings screen needed — just pass it at launch time.
class Config {
  Config._();

  static const String apiHost = String.fromEnvironment(
    'API_HOST',
    defaultValue: 'localhost',
  );

  static const String apiPort = String.fromEnvironment(
    'API_PORT',
    defaultValue: '8000',
  );

  static String get baseUrl => 'http://$apiHost:$apiPort';

  /// Request timeout — Gemini can be slow under load.
  static const Duration requestTimeout = Duration(seconds: 45);
}
