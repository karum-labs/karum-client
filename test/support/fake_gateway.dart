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

/// `GET /api/v1/presets`' body, mirroring `karum-server/internal/presets`.
/// Tests that drive the full [KarumApp] need this so the landing page's
/// previous-run cards and the account page's campaign grid have something to
/// render — they are fetched, not hardcoded (PLAN.md §52).
Map<String, dynamic> presetsJson() => {
  'presets': [
    {
      'id': 'austin-wholesale',
      'group_id': 'austin',
      'group_label': 'Sola in Austin',
      'group_description':
          'A mezcal aperitif with no Qloo brand entity. The seed swaps in '
          'verified substitutes.',
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
        {
          'id': '41C4BB40-E667-416F-9541-63FD7E7FFFF5',
          'name': 'Ilegal Mezcal',
          'type': 'urn:entity:brand',
        },
        {
          'id': 'BAF6317A-DF94-4C90-92AE-63F86560C21B',
          'name': 'Khruangbin',
          'type': 'urn:entity:artist',
        },
      ],
      'skus': [
        {'id': 'sola-aperitif', 'name': 'Sola Yuzu-Mezcal Aperitif'},
        {'id': 'sola-spritz', 'name': 'Sola Mezcal Spritz'},
      ],
      'campaign_id': 'cmp-austin-wholesale',
    },
    {
      'id': 'brooklyn-flagship',
      'group_id': 'brooklyn',
      'group_label': 'Ceramics and matcha in Brooklyn',
      'group_description':
          'One seed, two questions: where to open, and who to collaborate '
          'with.',
      'label': 'Ceramics and matcha in Brooklyn',
      'button_label': 'Try: Ceramics & Matcha — Flagship',
      'description':
          'Design retail, ceramics studios, and matcha · corridor heatmap',
      'brand': 'Muji',
      'city': 'Brooklyn, NY, US',
      'mode': 'flagship',
      'point': {'lat': 40.7172, 'lng': -73.9566},
      'radius_meters': 8000,
      'heatmap_radius': 10000,
      'category_tags': ['urn:tag:genre:place:restaurant:cafe'],
      'seeds': [
        {
          'id': 'E12201A5-CC50-40AF-97AE-C54A2CA303F7',
          'name': 'Muji',
          'type': 'urn:entity:brand',
        },
      ],
      'skus': [
        {'id': 'muji-ceramics', 'name': 'Muji Ceramic Tableware'},
      ],
      'campaign_id': 'cmp-brooklyn-flagship',
    },
    {
      'id': 'brooklyn-collab',
      'group_id': 'brooklyn',
      'group_label': 'Ceramics and matcha in Brooklyn',
      'group_description':
          'One seed, two questions: where to open, and who to collaborate '
          'with.',
      'label': 'Brooklyn collab',
      'button_label': 'Try: Ceramics & Matcha — Collab',
      'description': 'Galleries and ceramics studios · activation partners',
      'brand': 'Muji',
      'city': 'Brooklyn, NY, US',
      'mode': 'collab',
      'point': {'lat': 40.7172, 'lng': -73.9566},
      'radius_meters': 8000,
      'category_tags': [
        'urn:tag:genre:place:art_gallery',
        'urn:tag:genre:place:ceramics',
      ],
      'seeds': [
        {
          'id': 'E12201A5-CC50-40AF-97AE-C54A2CA303F7',
          'name': 'Muji',
          'type': 'urn:entity:brand',
        },
      ],
      'skus': [
        {'id': 'muji-ceramics', 'name': 'Muji Ceramic Tableware'},
      ],
      'campaign_id': 'cmp-brooklyn-collab',
    },
    {
      'id': 'mumbai-colaba-wholesale',
      'group_id': 'colaba',
      'group_label': 'Cacao and coffee in Colaba',
      'group_description':
          'Brand-typed search misses; the seed resolves Mumbai specialty '
          'cafés.',
      'label': 'Cacao and coffee in Colaba',
      'button_label': 'Try: Cacao & Coffee in Colaba, Mumbai',
      'description': 'Specialty cacao and coffee · cafés',
      'brand': 'Subko',
      'city': 'Mumbai, MH, IN',
      'mode': 'wholesale',
      'point': {'lat': 18.93, 'lng': 72.83},
      'radius_meters': 8000,
      'category_tags': ['urn:tag:genre:place:restaurant:cafe'],
      'seeds': [
        {
          'id': '0DE2E903-CCB5-4523-BAF0-3EC15514248C',
          'name': 'Mary Lodge by Subko',
          'type': 'urn:entity:place',
        },
      ],
      'skus': [
        {'id': 'subko-cacao', 'name': 'Subko Specialty Cacao'},
      ],
      'campaign_id': 'cmp-mumbai-colaba-wholesale',
    },
  ],
};

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
      if (request.method == 'GET' && path == '/api/v1/presets') {
        return jsonResponse(presetsJson());
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
