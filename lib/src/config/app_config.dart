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

  /// Browser key for the Maps JavaScript API.
  ///
  /// Empty keeps the OpenStreetMap/CARTO map. `make local` passes the value
  /// from `GOOGLE_MAPS_WEB_KEY`. The key is restricted to that one API, so a
  /// map load cannot spend the Places or Routes budget.
  static const String googleMapsWebKey = String.fromEnvironment(
    'GOOGLE_MAPS_WEB_KEY',
  );
}
