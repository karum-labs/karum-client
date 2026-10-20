import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:karum/main.dart';
import 'package:karum/src/api/gateway_client.dart';

/// A one-door wholesale campaign shaped like `GET /api/v1/scout/:id` once the
/// run is ready: scores, Places enrichment, menu citations, and a trace.
Map<String, dynamic> _campaignJson() => {
  'job_id': 'run-0001',
  'campaign_id': 'cmp-austin-wholesale',
  'state': 'ready',
  'mode': 'wholesale',
  'city': 'Austin, TX, US',
  'point': {'lat': 30.2672, 'lng': -97.7431},
  'point_attribution': 'Map data © Google',
  'radius_meters': 8000,
  'brand': {
    'name': 'Sola',
    'skus': [
      {'id': 'sola-aperitif', 'name': 'Sola Yuzu-Mezcal Aperitif'},
    ],
  },
  'doors': [
    {
      'id': 'd-1',
      'name': "Whisler's",
      'rank': 1,
      'scores': {
        'cultural_affinity': {'value': 0.91, 'source': 'qloo_fact'},
        'shelf_opportunity': {'value': 0.75, 'source': 'model_inference'},
        'composite': {
          'value': 0.72,
          'display': 72,
          'source': 'model_inference',
        },
      },
      'shared_tags': [
        {'urn': 'urn:tag:genre:place:restaurant:bar', 'label': 'Bars'},
      ],
      'enrichment': {
        'address': '307 E 6th St, Austin, TX',
        'open_status': 'operational',
        'lat': 30.2672,
        'lng': -97.7431,
      },
      'pitch': {'script': "Whisler's ranks first of 25.", 'template': true},
      'menu': {
        'summary': 'Two mezcal competitors on the list.',
        'shelf_unknown': true,
        'competitor_count': 2,
        'incumbents': [
          {
            'name': 'Del Maguey',
            'sources': [
              {'url': 'https://example.com/menu', 'title': 'Spring menu'},
            ],
          },
        ],
        'sources': [
          {'url': 'https://example.com/list', 'title': 'Shelf list'},
        ],
      },
      'evidence_ids': ['ev-0001'],
    },
  ],
  'skip_list': [
    {'id': 'd-2', 'name': "Maggie Mae's", 'reason': 'low_affinity'},
  ],
  'evidence': [
    {
      'id': 'ev-0001',
      'endpoint': '/v2/insights',
      'parameters': ['rank=1'],
      'result_count': 25,
      'source': 'qloo_fact',
    },
  ],
  'baseline': {
    'text': 'Wide-band advice with no taste data.',
    'ungrounded': true,
  },
  'warnings': [],
  'trace': [
    {
      'sequence': 1,
      'cursor': '1',
      'stage': 'baseline',
      'elapsed_ms': 120,
      'cache_hit': false,
      'detail': 'LLM-only baseline stored',
    },
    {
      'sequence': 2,
      'cursor': '2',
      'stage': 'persist',
      'elapsed_ms': 900,
      'cache_hit': false,
      'detail': 'ready',
    },
  ],
};

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

/// Records every scout POST so tests can assert the locked body and key.
class _Gateway {
  _Gateway({this.runningFetches = 1});

  /// How many job fetches report `running` before the campaign is ready. A
  /// value above one keeps the workspace in its polling fallback long enough
  /// for a test to observe it.
  final int runningFetches;

  final List<http.Request> scoutPosts = [];
  int jobFetches = 0;

  GatewayClient client() => GatewayClient(
    baseUrl: 'http://test',
    httpClient: MockClient((request) async {
      final path = request.url.path;
      if (request.method == 'GET' && path == '/health') {
        return _json({
          'service': 'gateway',
          'status': 'ok',
          'mode': 'fixture',
          'version': 'test',
          'time': '2026-10-19T12:00:00Z',
        });
      }
      if (request.method == 'POST' && path == '/api/v1/scout') {
        scoutPosts.add(request);
        return _json({
          'job_id': 'run-0001',
          'campaign_id': 'cmp-austin-wholesale',
          'state': 'running',
          'trace_cursor': '0',
        }, 202);
      }
      if (request.method == 'GET' && path == '/api/v1/scout/run-0001') {
        jobFetches += 1;
        if (jobFetches <= runningFetches) {
          return _json({
            'job_id': 'run-0001',
            'campaign_id': 'cmp-austin-wholesale',
            'state': 'running',
            'trace_cursor': '0',
          });
        }
        return _json(_campaignJson());
      }
      // The demo stream drops; the workspace must poll instead of guessing.
      return http.Response('stream unavailable', 503);
    }),
  );
}

void main() {
  testWidgets('judge path: preset click lands on a ready door board', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final gateway = _Gateway();
    await tester.pumpWidget(KarumApp(client: gateway.client()));
    await tester.pumpAndSettle();

    // The landing renders the locked samples.
    final preset = find.text('Try Sample: Sola Yuzu Mezcal in Austin, TX');
    expect(preset, findsOneWidget);

    await tester.ensureVisible(preset);
    await tester.pumpAndSettle();
    await tester.tap(preset);
    await tester.pumpAndSettle();

    // One POST, locked to the preset, carrying an idempotency key.
    expect(gateway.scoutPosts, hasLength(1));
    final body =
        jsonDecode(gateway.scoutPosts.single.body) as Map<String, dynamic>;
    expect(body['preset_id'], 'austin-wholesale');
    expect(body.containsKey('free_entry'), isFalse);
    expect(gateway.scoutPosts.single.headers['Idempotency-Key'], isNotEmpty);

    // The workspace shows the fixture banner and the ranked door.
    expect(find.textContaining('Fixture mode'), findsOneWidget);
    expect(find.text('Ready'), findsWidgets);
    expect(find.text("Whisler's"), findsWidgets);
    expect(find.textContaining('Whisler'), findsWidgets);
    // Menu findings carry clickable grounding citations on the card.
    expect(find.text('Spring menu'), findsOneWidget);
  });

  testWidgets('inspecting a sample carries its stored point into free entry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final gateway = _Gateway();
    await tester.pumpWidget(KarumApp(client: gateway.client()));
    await tester.pumpAndSettle();

    final inspect = find.text('Inspect this seed').first;
    await tester.ensureVisible(inspect);
    await tester.pumpAndSettle();
    await tester.tap(inspect);
    await tester.pumpAndSettle();

    final submit = find.text('Run this scout');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(gateway.scoutPosts, hasLength(1));
    final body =
        jsonDecode(gateway.scoutPosts.single.body) as Map<String, dynamic>;
    expect(body['free_entry'], isTrue);
    expect(body['point'], {'lat': 30.2672, 'lng': -97.7431});
    expect(body['seed_entities'], isNotEmpty);
  });

  testWidgets('free entry refuses an empty city without calling the gateway', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final gateway = _Gateway();
    await tester.pumpWidget(KarumApp(client: gateway.client()));
    await tester.pumpAndSettle();

    final submit = find.text('Run this scout');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.text('Add a city before running the scout.'), findsOneWidget);
    expect(gateway.scoutPosts, isEmpty);
  });

  testWidgets('a dropped trace stream falls back to polling', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final gateway = _Gateway(runningFetches: 2);
    await tester.pumpWidget(
      KarumApp(client: gateway.client(), initialRoute: '/scout/run-0001'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // The SSE 503 surfaces as a dropped-stream notice while the job runs.
    expect(find.textContaining('Trace stream dropped'), findsOneWidget);

    // The poller then picks up the ready campaign and the notice clears.
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();
    expect(find.text("Whisler's"), findsWidgets);
    expect(find.textContaining('Trace stream dropped'), findsNothing);
  });

  testWidgets('workspace lays out at a narrow 420 x 900 window', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final gateway = _Gateway();
    await tester.pumpWidget(
      KarumApp(client: gateway.client(), initialRoute: '/scout/run-0001'),
    );
    await tester.pumpAndSettle();

    // Below 1200 px the workspace uses trace/map/board tabs.
    expect(find.text('Trace (2)'), findsOneWidget);
    expect(find.text('Board (1)'), findsOneWidget);

    await tester.tap(find.text('Board (1)'));
    await tester.pumpAndSettle();
    expect(find.text("Whisler's"), findsWidgets);
  });
}
