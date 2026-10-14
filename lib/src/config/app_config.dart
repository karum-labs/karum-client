/// Compile-time and runtime configuration for the Karum client.
///
/// The gateway base URL is supplied at build/run time via `--dart-define`, so
/// pointing the app at local Compose or the production host is a switch rather
/// than a code change:
///
/// ```sh
/// # Local Compose
/// flutter run -d chrome --dart-define=GATEWAY_URL=http://localhost:8080
///
/// # Production
/// flutter build web --dart-define=GATEWAY_URL=https://gateway.example.com
/// ```
library;

/// Application-wide configuration resolved from `--dart-define`.
abstract final class AppConfig {
  /// The base URL of the Karum gateway.
  ///
  /// Falls back to `http://localhost:8080` (the local Compose port) when
  /// `GATEWAY_URL` is not supplied, so `flutter run` works out of the box. Any
  /// trailing slash is stripped by [GatewayClient] before requests are made.
  static const String gatewayBaseUrl = String.fromEnvironment(
    'GATEWAY_URL',
    defaultValue: 'http://localhost:8080',
  );
}
