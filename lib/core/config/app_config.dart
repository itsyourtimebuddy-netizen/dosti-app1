/// Everything that changes between "on my computer" and "live" lives here.
class AppConfig {
  AppConfig._();

  /// Address of the Dosti backend (no trailing path).
  ///
  /// Set it when you run or build the app, nothing to edit in code:
  ///   flutter run --dart-define=API_BASE_URL=http://192.168.1.5:3000
  ///   flutter build appbundle --dart-define=API_BASE_URL=https://api.yourdomain.com
  ///
  /// The default is what an Android *emulator* uses to reach the computer it runs on.
  /// A real phone needs your computer's WiFi IP (or a deployed https:// server).
  static const String _serverUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  /// [_serverUrl] without a trailing slash.
  static String get baseUrl =>
      _serverUrl.endsWith('/') ? _serverUrl.substring(0, _serverUrl.length - 1) : _serverUrl;

  /// Release builds must use https, otherwise logins and payments travel unprotected.
  static bool get isSecure => baseUrl.startsWith('https://');

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 20);
}
