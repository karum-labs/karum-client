import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'health_status.dart';

/// A failure talking to the gateway, carrying enough context for the UI to show
/// specific copy rather than a generic error.
class GatewayException implements Exception {
  const GatewayException(this.message, {this.statusCode});

  /// Human-readable description of what went wrong.
  final String message;

  /// HTTP status code, when the failure came from a non-2xx response.
  final int? statusCode;

  @override
  String toString() =>
      'GatewayException(${statusCode ?? 'network'}: $message)';
}

/// Thin HTTP client for the Karum gateway.
///
/// A [http.Client] can be injected for tests; otherwise a real client is used.
class GatewayClient {
  GatewayClient({http.Client? httpClient, String? baseUrl})
      : _http = httpClient ?? http.Client(),
        _baseUrl = _normalise(baseUrl ?? AppConfig.gatewayBaseUrl);

  final http.Client _http;
  final String _baseUrl;

  /// The gateway base URL with any trailing slash removed.
  String get baseUrl => _baseUrl;

  /// Fetches `GET /health` and returns the parsed [HealthStatus].
  ///
  /// Throws [GatewayException] on a network failure, a non-2xx status, or a
  /// payload that fails to parse.
  Future<HealthStatus> fetchHealth() async {
    final uri = Uri.parse('$_baseUrl/health');

    late final http.Response response;
    try {
      response = await _http.get(uri).timeout(const Duration(seconds: 10));
    } on http.ClientException catch (e) {
      throw GatewayException('could not reach the gateway at $uri: $e');
    } catch (e) {
      throw GatewayException('request to $uri failed: $e');
    }

    if (response.statusCode != 200) {
      throw GatewayException(
        'unexpected response from the gateway (HTTP ${response.statusCode})',
        statusCode: response.statusCode,
      );
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('health payload was not an object');
      }
      return HealthStatus.fromJson(decoded);
    } on FormatException catch (e) {
      throw GatewayException('could not parse the health payload: $e');
    }
  }

  /// Releases the underlying HTTP client.
  void close() => _http.close();

  static String _normalise(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;
}
