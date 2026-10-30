import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../data/presets.dart';
import 'auth_models.dart';
import 'health_status.dart';
import 'scout_models.dart';
import 'scout_request.dart';

/// A brand file attached to a pitch regeneration (PLAN.md §65).
class Attachment {
  const Attachment({required this.filename, required this.bytes});
  final String filename;
  final Uint8List bytes;
}

/// A city candidate returned with an HTTP 422 `ambiguous` response.
class CityCandidate {
  const CityCandidate({required this.formattedAddress, required this.point});

  final String formattedAddress;
  final GeoPoint point;

  factory CityCandidate.fromJson(Map<String, dynamic> json) => CityCandidate(
    formattedAddress: (json['formatted_address'] ?? '').toString(),
    point: GeoPoint.fromJson(json),
  );
}

/// A failure talking to the gateway, carrying enough context for the UI to show
/// specific copy rather than a generic error.
class GatewayException implements Exception {
  const GatewayException(
    this.message, {
    this.statusCode,
    this.code,
    this.candidates = const [],
  });

  /// Human-readable description of what went wrong.
  final String message;

  /// HTTP status code, when the failure came from a non-2xx response.
  final int? statusCode;

  /// The gateway's machine-readable error code, when present.
  final String? code;

  /// City candidates for an `ambiguous` geocode response.
  final List<CityCandidate> candidates;

  /// True when the operator has to choose a city point.
  bool get isAmbiguous => code == 'ambiguous' && candidates.isNotEmpty;

  /// True when the gateway reported a duplicate submission.
  bool get isConflict => statusCode == 409;

  /// True when the gateway rate-limited the request.
  bool get isRateLimited => statusCode == 429;

  /// True when the request failed validation.
  bool get isValidation => statusCode == 400 && code == 'validation';

  /// True when the session token is missing, expired, or rejected.
  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => 'GatewayException(${statusCode ?? 'network'}: $message)';
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
  String? _token;

  /// The gateway base URL with any trailing slash removed.
  String get baseUrl => _baseUrl;

  /// The current opaque session token, when signed in.
  String? get token => _token;

  /// Replaces the bearer token, for example when restoring a saved session.
  void setToken(String? token) {
    final trimmed = token?.trim();
    _token = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  /// Fetches `GET /health` and returns the parsed [HealthStatus].
  Future<HealthStatus> fetchHealth() async {
    final response = await _get(
      '/health',
      timeout: const Duration(seconds: 10),
    );
    return _parse(response, HealthStatus.fromJson);
  }

  /// Fetches `GET /api/v1/presets`, the locked previous-run catalogue.
  ///
  /// The four landing-page previous runs are not hardcoded in the client — this is
  /// the only place their brand, seed entities, and SKUs come from. The
  /// route is public: the catalogue is the same for every visitor (PLAN.md
  /// §52).
  Future<PresetCatalog> fetchPresets() async {
    final response = await _get(
      '/api/v1/presets',
      timeout: const Duration(seconds: 15),
    );
    return _parse(response, PresetCatalog.fromJson);
  }

  /// Fetches `GET /api/v1/account/campaigns`, the signed-in account's
  /// run-history list. Bearer token is attached automatically.
  ///
  /// The route requires a session: anonymous visitors get 401 and never see
  /// another account's campaigns (PLAN.md §49).
  Future<List<AccountCampaign>> fetchAccountCampaigns() async {
    final response = await _get(
      '/api/v1/account/campaigns',
      timeout: const Duration(seconds: 15),
    );
    final decoded = _decodeObject(response);
    final raw = decoded['campaigns'];
    if (raw is! List) {
      return const <AccountCampaign>[];
    }
    return raw
        .whereType<Map>()
        .map(
          (item) => AccountCampaign.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList(growable: false);
  }

  /// Signs in with an email and password and stores the returned token.
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _send(
      'POST',
      '/api/v1/auth/login',
      body: {'email': email, 'password': password},
      timeout: const Duration(seconds: 20),
    );
    final session = _parse(response, AuthSession.fromJson);
    _token = session.token;
    return session;
  }

  /// Signs into the preseeded judge account without collecting a password.
  ///
  /// The gateway returns 404 unless `HACKATHON_MODE=true`.
  Future<AuthSession> judgeLogin() async {
    final response = await _send(
      'POST',
      '/api/v1/auth/judge',
      timeout: const Duration(seconds: 20),
    );
    final session = _parse(response, AuthSession.fromJson);
    _token = session.token;
    return session;
  }

  /// Creates an account from an email and password and signs it in.
  Future<AuthSession> register({
    required String email,
    required String password,
  }) async {
    final response = await _send(
      'POST',
      '/api/v1/auth/register',
      body: {'email': email, 'password': password},
      timeout: const Duration(seconds: 20),
    );
    final session = _parse(response, AuthSession.fromJson);
    _token = session.token;
    return session;
  }

  /// Resolves the account attached to the current token.
  Future<AuthAccount> fetchMe() async {
    final response = await _get(
      '/api/v1/auth/me',
      timeout: const Duration(seconds: 15),
    );
    final decoded = _decodeObject(response);
    final rawAccount = decoded['account'];
    if (rawAccount is! Map) {
      throw const GatewayException(
        'the gateway did not return an account',
        statusCode: 200,
        code: 'invalid_payload',
      );
    }
    try {
      return AuthAccount.fromJson(
        rawAccount.map((key, value) => MapEntry(key.toString(), value)),
      );
    } on FormatException catch (e) {
      throw GatewayException('could not parse the account payload: $e');
    }
  }

  /// Revokes the current session and clears the local token.
  Future<void> logout() async {
    try {
      if (_token != null) {
        await _send(
          'POST',
          '/api/v1/auth/logout',
          timeout: const Duration(seconds: 15),
        );
      }
    } finally {
      _token = null;
    }
  }

  /// Creates a scout.
  ///
  /// The gateway answers with one of three 2xx statuses:
  ///
  /// - **202** — the pipeline was started and is still running.
  /// - **201** — the run completed synchronously and the response already
  ///   carries the finished campaign.
  /// - **200** — the gateway served a stored preset replay, so the run was
  ///   already done before this request arrived.
  ///
  /// Any 2xx is accepted, so the client does not branch on which one came
  /// back.
  Future<ScoutJob> createScout(
    ScoutRequest request, {
    String? idempotencyKey,
  }) async {
    final key = idempotencyKey ?? _newIdempotencyKey();
    final response = await _send(
      'POST',
      '/api/v1/scout',
      body: request.toJson(),
      headers: {'Idempotency-Key': key},
      timeout: const Duration(seconds: 120),
    );
    return _parse(response, ScoutJob.fromJson);
  }

  /// Fetches a job. The response is a compact job while running and the full
  /// campaign once ready.
  Future<ScoutJob> fetchScout(String jobId) async {
    final response = await _get(
      '/api/v1/scout/${Uri.encodeComponent(jobId)}',
      timeout: const Duration(seconds: 20),
    );
    return _parse(response, ScoutJob.fromJson);
  }

  /// Restores the newest run attached to a campaign id.
  Future<Campaign> fetchCampaign(String campaignId) async {
    final response = await _get(
      '/api/v1/campaigns/${Uri.encodeComponent(campaignId)}',
      timeout: const Duration(seconds: 20),
    );
    final decoded = _decodeObject(response);
    if (!decoded.containsKey('doors') && !decoded.containsKey('mode')) {
      throw const GatewayException(
        'This campaign has no completed scout yet. Run a scout to create one.',
        statusCode: 404,
        code: 'not_found',
      );
    }
    return Campaign.fromJson(decoded);
  }

  /// Streams trace events after [cursor]. The gateway closes the stream when
  /// the job reaches a terminal state.
  ///
  /// This path deliberately carries no request timeout: the stream is
  /// long-lived, and a timeout here would cut a healthy run off mid-flight.
  Stream<TraceEvent> streamEvents(String jobId, {int cursor = 0}) async* {
    final uri = Uri.parse(
      '$_baseUrl/api/v1/scout/${Uri.encodeComponent(jobId)}/events'
      '?cursor=$cursor',
    );
    final request = http.Request('GET', uri)
      ..headers['Accept'] = 'text/event-stream'
      ..headers['Cache-Control'] = 'no-cache';
    final token = _token;
    if (token != null) request.headers['Authorization'] = 'Bearer $token';

    late final http.StreamedResponse response;
    try {
      response = await _http.send(request);
    } on http.ClientException catch (e) {
      throw GatewayException('could not reach the trace stream at $uri: $e');
    } catch (e) {
      throw GatewayException('trace request to $uri failed: $e');
    }

    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      throw _errorFrom(response.statusCode, body);
    }

    String? data;
    final lines = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    await for (final line in lines) {
      if (line.isEmpty) {
        if (data != null && data.trim().isNotEmpty) {
          try {
            final decoded = jsonDecode(data);
            if (decoded is Map<String, dynamic>) {
              yield TraceEvent.fromJson(decoded);
            }
          } on FormatException {
            // A malformed event should not kill a live timeline; the next
            // event and the terminal campaign payload remain usable.
          }
          data = null;
        }
        continue;
      }
      if (line.startsWith('data:')) {
        final chunk = line.substring(5).trimLeft();
        data = data == null ? chunk : '$data\n$chunk';
      }
    }
    if (data != null && data.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) {
          yield TraceEvent.fromJson(decoded);
        }
      } on FormatException {
        // Ignore a partial trailing event.
      }
    }
  }

  /// Aborts a running job.
  Future<void> abortScout(String jobId) async {
    await _send(
      'POST',
      '/api/v1/scout/${Uri.encodeComponent(jobId)}/abort',
      timeout: const Duration(seconds: 20),
    );
  }

  /// Regenerates one door pitch and returns the updated campaign.
  /// ``instructions`` is the operator's direction for the redraft (PLAN.md §65):
  /// a suggestion, not a rule. ``attachment`` optionally uploads a brand file
  /// (.txt, .md, .pdf, capped at 2 MB) whose extracted text informs the pitch.
  Future<Campaign> regenerateDoorPitch(
    String jobId,
    String doorId, {
    String instructions = '',
    Attachment? attachment,
  }) async {
    final path = '/api/v1/scout/${Uri.encodeComponent(jobId)}/drafts/doors/'
        '${Uri.encodeComponent(doorId)}';
    if (attachment != null) {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl$path'),
      );
      request.headers['Accept'] = 'application/json';
      final token = _token;
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      if (instructions.isNotEmpty) {
        request.fields['instructions'] = instructions;
      }
      request.files.add(
        http.MultipartFile.fromBytes(
          'attachment',
          attachment.bytes,
          filename: attachment.filename,
        ),
      );
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return _parse(response, Campaign.fromJson);
      }
      throw _errorFrom(response.statusCode, response.body);
    }
    final response = await _send(
      'POST',
      path,
      body: instructions.isNotEmpty ? {'instructions': instructions} : null,
      timeout: const Duration(seconds: 75),
    );
    return _parse(response, Campaign.fromJson);
  }

  /// Exports a single-door pitch as a one-page PDF (PLAN.md §66).
  Future<Uint8List> exportPitch(String jobId, String doorId) async {
    final response = await _send(
      'POST',
      '/api/v1/scout/${Uri.encodeComponent(jobId)}/drafts/doors/'
          '${Uri.encodeComponent(doorId)}/export',
      timeout: const Duration(seconds: 75),
    );
    return response.bodyBytes;
  }

  /// Downloads the server-rendered run-sheet or flagship site brief.
  Future<Uint8List> downloadDraft(
    String jobId, {
    required bool siteBrief,
  }) async {
    final path = siteBrief
        ? '/api/v1/scout/${Uri.encodeComponent(jobId)}/drafts/site-brief'
        : '/api/v1/scout/${Uri.encodeComponent(jobId)}/drafts/run-sheet';
    final response = await _send(
      'POST',
      path,
      timeout: const Duration(seconds: 75),
    );
    if (response.statusCode != 200) {
      throw _errorFrom(response.statusCode, response.body);
    }
    return response.bodyBytes;
  }

  /// Sends one door's pitch by email through the gateway (PLAN.md §67).
  /// ``confirm`` must be true; the visitor edits subject and body before
  /// sending. Sending goes through the gateway, never the browser.
  Future<void> sendContact(
    String jobId,
    String doorId, {
    required String recipient,
    required bool confirm,
    String subject = '',
    String body = '',
  }) async {
    final response = await _send(
      'POST',
      '/api/v1/scout/${Uri.encodeComponent(jobId)}/drafts/doors/'
          '${Uri.encodeComponent(doorId)}/contact',
      body: {
        'recipient': recipient,
        'confirm': confirm,
        'subject': subject,
        'body': body,
      },
      timeout: const Duration(seconds: 30),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    throw _errorFrom(response.statusCode, response.body);
  }

  /// Releases the underlying HTTP client.
  void close() => _http.close();

  Future<http.Response> _get(String path, {required Duration timeout}) =>
      _send('GET', path, timeout: timeout);

  Future<http.Response> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? headers,
    required Duration timeout,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final request = http.Request(method, uri);
    request.headers['Accept'] = 'application/json';
    final token = _token;
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (headers != null) request.headers.addAll(headers);
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    late http.Response response;
    try {
      // The declared timeout covers the whole request, headers and body. A
      // gateway that accepts the connection and then goes quiet must not hold
      // the UI open forever, so the request future is bounded here rather
      // than in the callers.
      response = await _perform(request).timeout(timeout);
    } on http.ClientException catch (e) {
      throw GatewayException('could not reach the gateway at $uri: $e');
    } on TimeoutException {
      throw GatewayException(
        'the gateway did not answer at $uri within ${timeout.inSeconds}s',
        statusCode: 504,
        code: 'timeout',
      );
    } catch (e) {
      throw GatewayException('request to $uri failed: $e');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }
    throw _errorFrom(response.statusCode, response.body);
  }

  /// Sends [request] and reads the whole response body.
  ///
  /// The trace stream does not use this: a live event stream is long-lived by
  /// design, so a request timeout would kill a healthy run. The stream owns
  /// its own lifecycle and is closed by the gateway at the terminal state.
  Future<http.Response> _perform(http.Request request) async {
    final streamed = await _http.send(request);
    return http.Response.fromStream(streamed);
  }

  T _parse<T>(http.Response response, T Function(Map<String, dynamic>) parse) {
    final decoded = _decodeObject(response);
    try {
      return parse(decoded);
    } on FormatException catch (e) {
      throw GatewayException('could not parse the gateway payload: $e');
    }
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
      throw const FormatException('payload was not an object');
    } on FormatException catch (e) {
      throw GatewayException('could not parse the gateway payload: $e');
    }
  }

  GatewayException _errorFrom(int status, String body) {
    String? code;
    String? message;
    final candidates = <CityCandidate>[];
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        code = decoded['error']?.toString();
        message = decoded['message']?.toString();
        final rawCandidates = decoded['candidates'];
        if (rawCandidates is List) {
          for (final raw in rawCandidates) {
            if (raw is Map) {
              candidates.add(
                CityCandidate.fromJson(
                  raw.map((key, value) => MapEntry(key.toString(), value)),
                ),
              );
            }
          }
        }
      }
    } on FormatException {
      // Non-JSON error pages are common from a proxy; use the status fallback.
    }

    final resolved = switch (status) {
      429 => 'The gateway is rate-limiting requests (429). Wait a few seconds and try again.',
      409 when code == 'email_taken' =>
        message ?? 'An account with this email already exists.',
      409 => 'This request was already submitted with a different body. Reload the form and try again.',
      422 when code == 'ambiguous' =>
        message ?? 'The city query is ambiguous. Choose a candidate.',
      400 => message ?? 'The request did not pass validation.',
      401 => message ?? 'Your session has expired. Sign in again to continue.',
      404 => message ?? 'The requested job or campaign was not found.',
      503 || 502 => message ?? 'An upstream service is unavailable. The campaign was left unchanged.',
      _ => message ?? 'The gateway returned HTTP $status.',
    };

    return GatewayException(
      resolved,
      statusCode: status,
      code: code,
      candidates: List.unmodifiable(candidates),
    );
  }

  static String _normalise(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  static String _newIdempotencyKey() {
    final now = DateTime.now().microsecondsSinceEpoch;
    // Dart's web `nextInt` requires 0 < max < 2^32, so 1 << 32 throws a
    // RangeError in the browser even though the VM accepts it.
    final salt = Random.secure().nextInt(1 << 31).toRadixString(16);
    return 'karum-$now-$salt';
  }
}
