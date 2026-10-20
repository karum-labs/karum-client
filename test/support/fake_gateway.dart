import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:karum/src/api/gateway_client.dart';

/// A one-door wholesale campaign shaped like `GET /api/v1/scout/:id` once the
/// run is ready: scores, Places enrichment, menu citations, and a trace.
Map<String, dynamic> campaignJson() => {
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

http.Response jsonResponse(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

/// Records every scout POST so tests can assert the locked body and key.
class FakeGateway {
  FakeGateway({this.runningFetches = 1});

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
        return jsonResponse({
          'service': 'gateway',
          'status': 'ok',
          'mode': 'fixture',
          'version': 'test',
          'time': '2026-10-19T12:00:00Z',
        });
      }
      if (request.method == 'POST' && path == '/api/v1/scout') {
        scoutPosts.add(request);
        return jsonResponse({
          'job_id': 'run-0001',
          'campaign_id': 'cmp-austin-wholesale',
          'state': 'running',
          'trace_cursor': '0',
        }, 202);
      }
      if (request.method == 'GET' && path == '/api/v1/scout/run-0001') {
        jobFetches += 1;
        if (jobFetches <= runningFetches) {
          return jsonResponse({
            'job_id': 'run-0001',
            'campaign_id': 'cmp-austin-wholesale',
            'state': 'running',
            'trace_cursor': '0',
          });
        }
        return jsonResponse(campaignJson());
      }
      // The demo stream drops; the workspace must poll instead of guessing.
      return http.Response('stream unavailable', 503);
    }),
  );
}
