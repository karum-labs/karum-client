/// Models returned by the Karum gateway's `/health` endpoint.
library;

/// How the gateway is currently operating.
enum GatewayMode {
  /// Real upstream credentials are present; outbound calls go to live APIs.
  live,

  /// Replaying recorded payloads; no outbound network calls.
  fixture,

  /// An upstream dependency is unavailable; running the deterministic
  /// autopilot fallback.
  degraded,
}

/// Parsed payload of `GET /health`.
class HealthStatus {
  const HealthStatus({
    required this.service,
    required this.status,
    required this.mode,
    this.version,
    this.uptimeSeconds,
  });

  /// The stable name of the gateway process.
  final String service;

  /// `"ok"` when the process is serving traffic.
  final String status;

  /// The operational mode, shown as a banner in the UI.
  final GatewayMode mode;

  /// Build version, when provided.
  final String? version;

  /// How long the process has been running, in seconds.
  final int? uptimeSeconds;

  /// True when the gateway reports a healthy status.
  bool get isHealthy => status == 'ok';

  /// Builds a [HealthStatus] from a decoded JSON map.
  ///
  /// Throws a [FormatException] if the payload is missing required fields or
  /// carries an unknown mode, so callers surface a parse error rather than
  /// silently mis-mapping state.
  factory HealthStatus.fromJson(Map<String, dynamic> json) {
    final service = json['service'];
    final status = json['status'];
    final mode = json['mode'];

    if (service is! String || status is! String || mode is! String) {
      throw const FormatException('health payload missing required fields');
    }

    return HealthStatus(
      service: service,
      status: status,
      mode: _modeFromString(mode),
      version: json['version'] as String?,
      uptimeSeconds: (json['uptime_seconds'] as num?)?.toInt(),
    );
  }

  static GatewayMode _modeFromString(String value) {
    return GatewayMode.values.firstWhere(
      (m) => m.name == value,
      orElse: () => throw FormatException('unknown mode: $value'),
    );
  }
}
