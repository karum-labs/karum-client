import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:karum/src/api/auth_models.dart';
import 'package:karum/src/api/gateway_client.dart';
import 'package:karum/src/api/health_status.dart';
import 'package:karum/src/api/scout_models.dart';
import 'package:karum/src/api/scout_request.dart';

GatewayClient _client(MockClientHandler handler) =>
    GatewayClient(httpClient: MockClient(handler), baseUrl: 'http://test');

void main() {
  test('createScout posts the body with an Idempotency-Key', () async {
    late http.Request captured;
    final client = _client((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'job_id': 'run-0001',
          'campaign_id': 'cmp-austin-wholesale',
          'state': 'running',
          'trace_cursor': '0',
        }),
        202,
        headers: {'content-type': 'application/json'},
      );
    });

    final job = await client.createScout(
      ScoutRequest.preset('austin-wholesale'),
      idempotencyKey: 'karum-test-key',
    );

    expect(captured.method, 'POST');
    expect(captured.url.path, '/api/v1/scout');
    expect(captured.headers['Idempotency-Key'], 'karum-test-key');
    expect(captured.headers['Content-Type'], contains('application/json'));
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['preset_id'], 'austin-wholesale');
    // Empty optional fields are omitted so equivalent forms hash the same.
    expect(body.containsKey('free_entry'), isFalse);
    expect(body.containsKey('city'), isFalse);

    expect(job.jobId, 'run-0001');
    expect(job.state, JobState.running);
    expect(job.isRunning, isTrue);
    expect(job.hasCampaign, isFalse);
  });

  test('createScout generates a key when none is supplied', () async {
    late http.Request captured;
    final client = _client((request) async {
      captured = request;
      return http.Response(
        jsonEncode({'job_id': 'run-0002', 'state': 'running'}),
        202,
      );
    });

    await client.createScout(
      ScoutRequest.freeEntry(
        city: 'Austin',
        mode: ScoutMode.wholesale,
        radiusMeters: 8000,
        brandName: 'Sola',
        skus: const [],
        seedEntities: const [
          SeedEntity(id: 'seed-1', type: 'urn:entity:brand', name: 'Sola'),
        ],
        brandQuery: '',
        fallbackQueries: const [],
        categoryTags: const ['urn:tag:genre:place:restaurant:bar'],
        point: null,
      ),
    );

    expect(captured.headers['Idempotency-Key'], isNotNull);
    expect(captured.headers['Idempotency-Key']!.isNotEmpty, isTrue);
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['free_entry'], isTrue);
    expect(body['city'], 'Austin');
    expect(body['radius_meters'], 8000);
  });

  test('maps a 422 ambiguous response onto candidates', () async {
    final client = _client(
      (request) async => http.Response(
        jsonEncode({
          'error': 'ambiguous',
          'message': 'more than one city matched',
          'candidates': [
            {
              'formatted_address': 'Austin, TX, USA',
              'lat': 30.2672,
              'lng': -97.7431,
            },
            {
              'formatted_address': 'Austin, MN, USA',
              'lat': 43.6666,
              'lng': -92.9746,
            },
          ],
        }),
        422,
        headers: {'content-type': 'application/json'},
      ),
    );

    await expectLater(
      client.createScout(ScoutRequest.preset('austin-wholesale')),
      throwsA(
        isA<GatewayException>()
            .having((e) => e.isAmbiguous, 'isAmbiguous', isTrue)
            .having((e) => e.statusCode, 'statusCode', 422)
            .having((e) => e.candidates, 'candidates', hasLength(2))
            .having(
              (e) => e.candidates.first.formattedAddress,
              'first candidate',
              'Austin, TX, USA',
            )
            .having(
              (e) => e.candidates.first.point,
              'first point',
              const GeoPoint(30.2672, -97.7431),
            ),
      ),
    );
  });

  test('maps 409, 429, and 503 onto specific copy', () async {
    Future<GatewayException> failure(int status, String body) async {
      final client = _client(
        (request) async => http.Response(
          body,
          status,
          headers: {'content-type': 'application/json'},
        ),
      );
      try {
        await client.fetchScout('run-0001');
      } on GatewayException catch (error) {
        return error;
      }
      fail('expected a GatewayException');
    }

    final conflict = await failure(409, '{}');
    expect(conflict.isConflict, isTrue);
    expect(conflict.message, contains('already submitted'));

    final limited = await failure(429, 'slow down');
    expect(limited.isRateLimited, isTrue);
    expect(limited.message, contains('429'));

    final unavailable = await failure(503, '');
    expect(unavailable.statusCode, 503);
    expect(unavailable.message, contains('unavailable'));
  });

  test('streamEvents parses SSE frames and resumes from a cursor', () async {
    late http.Request captured;
    final client = _client((request) async {
      captured = request;
      return http.Response(
        'event: trace\n'
        'data: {"sequence":3,"cursor":"3","stage":"scout","elapsed_ms":250,'
        '"cache_hit":false,"detail":"2 doors, 1 skips"}\n'
        '\n'
        'event: trace\n'
        'data: {"sequence":4,"cursor":"4","stage":"persist",'
        '"elapsed_ms":310,"cache_hit":false,"detail":"ready"}\n'
        '\n',
        200,
        headers: {'content-type': 'text/event-stream'},
      );
    });

    final events = await client.streamEvents('run-0007', cursor: 2).toList();

    expect(captured.url.path, '/api/v1/scout/run-0007/events');
    expect(captured.url.queryParameters['cursor'], '2');
    expect(events, hasLength(2));
    expect(events.first.sequence, 3);
    expect(events.first.cursor, '3');
    expect(events.first.stageLabel, 'Door ranking');
    expect(events.last.stageLabel, 'Campaign stored');
    expect(events.last.elapsedLabel, '0.3s');
  });

  test('streamEvents surfaces a non-200 as a GatewayException', () async {
    final client = _client(
      (request) async => http.Response(
        jsonEncode({'error': 'not_found', 'message': 'no such job'}),
        404,
      ),
    );

    await expectLater(
      client.streamEvents('missing').toList(),
      throwsA(
        isA<GatewayException>().having((e) => e.statusCode, 'statusCode', 404),
      ),
    );
  });

  test('health carries the gateway-owned hackathon flag', () {
    final health = HealthStatus.fromJson({
      'service': 'gateway',
      'status': 'ok',
      'mode': 'fixture',
      'hackathon_mode': true,
    });
    expect(health.hackathonMode, isTrue);
  });

  test('login stores the token and attaches it to later requests', () async {
    final requests = <http.Request>[];
    final client = _client((request) async {
      requests.add(request);
      switch (request.url.path) {
        case '/api/v1/auth/login':
          return http.Response(
            jsonEncode({
              'token': 'tok-1',
              'expires_at': '2026-11-01T00:00:00Z',
              'account': {
                'id': 'acct-judge',
                'email': 'judge@karum.demo',
                'display_name': 'Karum Judge',
                'is_judge': true,
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        case '/api/v1/auth/me':
          return http.Response(
            jsonEncode({
              'account': {
                'id': 'acct-judge',
                'email': 'judge@karum.demo',
                'display_name': 'Karum Judge',
                'is_judge': true,
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        case '/api/v1/auth/logout':
          return http.Response('', 204);
        default:
          fail('unexpected request: ${request.method} ${request.url}');
      }
    });

    final session = await client.login(
      email: 'judge@karum.demo',
      password: 'secret',
    );
    expect(session, isA<AuthSession>());
    expect(session.account.isJudge, isTrue);
    expect(client.token, 'tok-1');

    final loginBody = jsonDecode(requests.first.body) as Map<String, dynamic>;
    expect(loginBody['email'], 'judge@karum.demo');
    expect(loginBody['password'], 'secret');

    final account = await client.fetchMe();
    expect(account.id, 'acct-judge');
    expect(requests.last.headers['Authorization'], 'Bearer tok-1');

    await client.logout();
    expect(client.token, isNull);
    expect(requests.last.url.path, '/api/v1/auth/logout');
    expect(requests.last.headers['Authorization'], 'Bearer tok-1');
  });

  test('judgeLogin uses the one-click endpoint and stores its token', () async {
    final client = _client(
      (request) async => http.Response(
        jsonEncode({
          'token': 'tok-judge',
          'account': {
            'id': 'acct-judge',
            'email': 'judge@karum.demo',
            'display_name': 'Karum Judge',
            'is_judge': true,
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );

    final session = await client.judgeLogin();
    expect(session.token, 'tok-judge');
    expect(client.token, 'tok-judge');
  });

  // PLAN.md §52: the four previous-run cards come from the gateway, not hardcoded
  // Dart constants.
  test('fetchPresets parses the catalogue, including a Brooklyn group', () async {
    final client = _client(
      (request) async => http.Response(
        jsonEncode({
          'presets': [
            {
              'id': 'austin-wholesale',
              'group_id': 'austin',
              'group_label': 'Sola in Austin',
              'group_description': 'A mezcal aperitif.',
              'label': 'Sola in Austin',
              'button_label': 'Try: Sola Yuzu Mezcal in Austin, TX',
              'description': 'Mezcal aperitif · bars and restaurants',
              'brand': 'Sola',
              'city': 'Austin, TX, US',
              'mode': 'wholesale',
              'point': {'lat': 30.2672, 'lng': -97.7431},
              'radius_meters': 8000,
              'category_tags': ['urn:tag:genre:place:restaurant:bar'],
              'seeds': [
                {
                  'id': '32F867B9-E6DF-44C3-BCE4-40160C7ED5E4',
                  'name': 'Aesop',
                  'type': 'urn:entity:brand',
                },
              ],
              'skus': [
                {'id': 'sola-aperitif', 'name': 'Sola Yuzu-Mezcal Aperitif'},
              ],
              'campaign_id': 'cmp-austin-wholesale',
            },
            {
              'id': 'brooklyn-flagship',
              'group_id': 'brooklyn',
              'group_label': 'Ceramics and matcha in Brooklyn',
              'group_description': 'One seed, two questions.',
              'label': 'Ceramics and matcha in Brooklyn',
              'button_label': 'Try: Ceramics & Matcha — Flagship',
              'description': 'Design retail',
              'brand': 'Muji',
              'city': 'Brooklyn, NY, US',
              'mode': 'flagship',
              'point': {'lat': 40.7172, 'lng': -73.9566},
              'radius_meters': 8000,
              'category_tags': ['urn:tag:genre:place:restaurant:cafe'],
              'seeds': <Map<String, Object>>[],
              'skus': <Map<String, Object>>[],
              'campaign_id': 'cmp-brooklyn-flagship',
            },
            {
              'id': 'brooklyn-collab',
              'group_id': 'brooklyn',
              'group_label': 'Ceramics and matcha in Brooklyn',
              'group_description': 'One seed, two questions.',
              'label': 'Brooklyn collab',
              'button_label': 'Try: Ceramics & Matcha — Collab',
              'description': 'Galleries',
              'brand': 'Muji',
              'city': 'Brooklyn, NY, US',
              'mode': 'collab',
              'point': {'lat': 40.7172, 'lng': -73.9566},
              'radius_meters': 8000,
              'category_tags': ['urn:tag:genre:place:art_gallery'],
              'seeds': <Map<String, Object>>[],
              'skus': <Map<String, Object>>[],
              'campaign_id': 'cmp-brooklyn-collab',
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );

    final catalog = await client.fetchPresets();
    expect(catalog.all, hasLength(3));
    expect(catalog.all.first.buttonLabel, contains('Sola Yuzu Mezcal'));
    expect(catalog.all.first.seeds.single.name, 'Aesop');
    expect(catalog.all.first.skus.single.name, 'Sola Yuzu-Mezcal Aperitif');
    expect(catalog.all.first.campaignId, 'cmp-austin-wholesale');

    // Brooklyn's two variants collapse into one group, in server order.
    expect(catalog.groups, hasLength(2));
    final brooklyn = catalog.groups.firstWhere((g) => g.brand == 'Muji');
    expect(brooklyn.variants, hasLength(2));
    expect(brooklyn.variants.first.mode, ScoutMode.flagship);
    expect(brooklyn.variants.last.mode, ScoutMode.collab);
  });

  test('a 401 is marked as an expired session', () async {
    final client = _client(
      (request) async => http.Response(
        jsonEncode({'error': 'unauthorized', 'message': 'sign in is required'}),
        401,
        headers: {'content-type': 'application/json'},
      ),
    )..setToken('expired');

    await expectLater(
      client.fetchMe(),
      throwsA(
        isA<GatewayException>()
            .having((e) => e.isUnauthorized, 'isUnauthorized', isTrue)
            .having((e) => e.message, 'message', contains('sign in')),
      ),
    );
  });
}
