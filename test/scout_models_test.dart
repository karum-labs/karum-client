import 'package:flutter_test/flutter_test.dart';
import 'package:karum/src/api/scout_models.dart';

/// A campaign payload shaped exactly like the gateway's `campaignOf` output,
/// including the menu findings and heatmap cells added for the map and the
/// evidence drawer.
Map<String, dynamic> _campaignJson() => {
  'job_id': 'run-0007',
  'campaign_id': 'cmp-austin-wholesale',
  'state': 'ready',
  'mode': 'wholesale',
  'city': 'Austin',
  'point': {'lat': 30.2672, 'lng': -97.7431},
  'point_attribution': 'Map data © Google',
  'radius_meters': 8000,
  'brand': {
    'name': 'Ilegal Mezcal',
    'skus': [
      {'id': 'sk-espadin', 'name': 'Espadín Joven'},
    ],
  },
  'formula': 'S_door = 0.50·A_taste + 0.30·O_shelf + 0.20·D_demo',
  'doors': [
    {
      'id': 'd-1',
      'name': "Whisler's",
      'rank': 1,
      'scores': {
        'cultural_affinity': {
          'value': 0.91,
          'raw': 0.91,
          'source': 'model_inference',
          'inputs': ['rank=1', 'shortlist=25'],
        },
        'shelf_opportunity': {
          'value': 0.75,
          'source': 'model_inference',
        },
        'composite': {'value': 0.72, 'display': 72, 'source': 'model_inference'},
      },
      'shared_tags': [
        {'urn': 'urn:tag:genre:place:restaurant:bar', 'label': 'Bars'},
      ],
      'enrichment': {
        'address': '307 E 6th St, Austin, TX',
        'hours': 'Monday: 4 PM–2 AM',
        'website': 'https://example.com/whislers',
        'open_status': 'operational',
        'unknown': false,
        'lat': 30.2672,
        'lng': -97.7431,
        'attribution': 'Map data © Google',
      },
      'pitch': {
        'script': 'Whisler\'s ranks first of 25 (ev-0001).',
        'sku': {'id': 'sk-espadin', 'name': 'Espadín Joven'},
        'battlecard': {
          'headline': 'Mezcal shelf is undifferentiated',
          'incumbent_name': 'Del Maguey',
          'talking_points': ['Only two mezcals on the back bar'],
        },
        'mode_paragraph': 'Wholesale placement wins on bottle-share.',
        'template': true,
      },
      'menu': {
        'summary': 'Two mezcal competitors on the list.',
        'shelf_unknown': true,
        'competitor_count': 2,
        'incumbents': [
          {
            'name': 'Del Maguey',
            'sources': [
              {
                'url': 'https://example.com/menu',
                'title': 'Spring 2026 menu',
              },
            ],
          },
        ],
        'sources': [
          {'url': 'https://example.com/list'},
        ],
      },
      'evidence_ids': ['ev-0001'],
    },
    {
      'id': 'd-2',
      'name': 'Here Nor There',
      'rank': 2,
      'scores': {
        'cultural_affinity': {'value': 0.64, 'source': 'model_inference'},
      },
      'shared_tags': [],
      'enrichment': {
        'open_status': 'unknown',
        'unknown': true,
      },
      'evidence_ids': ['ev-0001'],
    },
  ],
  'skip_list': [
    {
      'id': 'd-3',
      'name': "Maggie Mae's",
      'reason': 'competitor_saturation',
      'raw_affinity': 0.22,
      'floor': 0.3,
      'competitor_count': 6,
    },
  ],
  'evidence': [
    {
      'id': 'ev-0001',
      'endpoint': '/v2/insights',
      'parameters': ['filter.type=urn:entity:place'],
      'result_count': 25,
      'source': 'qloo_fact',
    },
  ],
  'baseline': {
    'text': 'Wide-band advice with no taste data.',
    'ungrounded': true,
    'venue_names': ['La Condesa', 'Suerte'],
  },
  'heatmap': {
    'available': true,
    'corridors': ['East Austin'],
    'anchors': ['The Roosevelt Room'],
    'cells': [
      {
        'lat': 30.262,
        'lng': -97.727,
        'affinity': 0.8,
        'affinity_rank': 3,
        'popularity': 0.4,
        'geohash': '9v6kp',
      },
    ],
    'cell_count': 1,
    'localities': 2,
  },
  'route': {
    'skipped': false,
    'failed': false,
    'stop_ids': ['d-1', 'd-2'],
    'legs': [
      {
        'from_id': 'start',
        'to_id': 'd-1',
        'distance_meters': 1200,
        'duration': '300s',
      },
      {
        'from_id': 'd-1',
        'to_id': 'd-2',
        'distance_meters': 900,
        'duration': '240s',
      },
    ],
    'attribution': 'Map data © Google',
  },
  'warnings': ['places unavailable: key is not configured'],
  'trace': [
    {
      'sequence': 1,
      'cursor': '1',
      'stage': 'baseline',
      'elapsed_ms': 120,
      'cache_hit': true,
      'detail': 'LLM-only baseline stored',
    },
    {
      'sequence': 2,
      'cursor': '2',
      'stage': 'menu_grounding',
      'elapsed_ms': 1520,
      'cache_hit': false,
      'detail': '2 findings',
    },
  ],
  'error_code': '',
  'error_message': '',
};

void main() {
  test('parses a full campaign in server order', () {
    final campaign = Campaign.fromJson(_campaignJson());

    expect(campaign.jobId, 'run-0007');
    expect(campaign.campaignId, 'cmp-austin-wholesale');
    expect(campaign.state, JobState.ready);
    expect(campaign.mode, ScoutMode.wholesale);
    expect(campaign.city, 'Austin');
    expect(campaign.point, const GeoPoint(30.2672, -97.7431));
    expect(campaign.radiusMeters, 8000);
    expect(campaign.brand.name, 'Ilegal Mezcal');
    expect(campaign.brand.skus.single.name, 'Espadín Joven');

    // The board never re-sorts: doors keep the gateway's order and ranks.
    expect(campaign.doors.map((door) => door.id).toList(), ['d-1', 'd-2']);
    expect(campaign.doors[0].rank, 1);
    expect(campaign.doors[1].rank, 2);
    expect(campaign.firstDoor?.name, "Whisler's");
  });

  test('scores carry percent and provenance', () {
    final door = Campaign.fromJson(_campaignJson()).doors.first;

    expect(door.compositePercent, 72);
    expect(door.scores.culturalAffinity?.percent, 91);
    expect(door.scores.culturalAffinity?.inputs, ['rank=1', 'shortlist=25']);
    expect(door.scores.composite?.source, 'model_inference');
    expect(door.scores.demographicAlignment, isNull);
  });

  test('door coordinates come from the Places enrichment', () {
    final campaign = Campaign.fromJson(_campaignJson());
    expect(campaign.doors[0].point, const GeoPoint(30.2672, -97.7431));
    expect(campaign.doors[0].enrichment?.openLabel, 'Open');
    // No Places geometry means no invented marker.
    expect(campaign.doors[1].point, isNull);
    expect(campaign.doors[1].enrichment?.openLabel, 'Places data unavailable');
  });

  test('menu findings and citations parse', () {
    final menu = Campaign.fromJson(_campaignJson()).doors.first.menu!;
    expect(menu.summary, 'Two mezcal competitors on the list.');
    expect(menu.shelfUnknown, isTrue);
    expect(menu.competitorCount, 2);
    expect(menu.incumbents.single.name, 'Del Maguey');
    expect(menu.incumbents.single.sources.single.url, 'https://example.com/menu');
    expect(menu.incumbents.single.sources.single.title, 'Spring 2026 menu');
    // A title-less source falls back to its URL.
    expect(menu.sources.single.title, 'https://example.com/list');
  });

  test('pitch keeps the template flag and battlecard', () {
    final pitch = Campaign.fromJson(_campaignJson()).doors.first.pitch!;
    expect(pitch.template, isTrue);
    expect(pitch.sku?.name, 'Espadín Joven');
    expect(pitch.battlecard?.incumbentName, 'Del Maguey');
    expect(pitch.battlecard?.talkingPoints.single, 'Only two mezcals on the back bar');
    expect(pitch.isEmpty, isFalse);
  });

  test('skip reasons map to plain English', () {
    final skip = Campaign.fromJson(_campaignJson()).skipList.single;
    expect(skip.reason, 'competitor_saturation');
    expect(skip.reasonLabel, 'Shelf already saturated');
    expect(skip.floor, 0.3);
    expect(skip.competitorCount, 6);
  });

  test('heatmap cells keep their affinity rank', () {
    final heatmap = Campaign.fromJson(_campaignJson()).heatmap!;
    expect(heatmap.available, isTrue);
    expect(heatmap.corridors, ['East Austin']);
    expect(heatmap.anchors, ['The Roosevelt Room']);
    expect(heatmap.cellCount, 1);
    expect(heatmap.localityCount, 2);
    final cell = heatmap.cells.single;
    expect(cell.point, const GeoPoint(30.262, -97.727));
    expect(cell.affinity, 0.8);
    expect(cell.rank, 3);
  });

  test('route keep its stops and legs in order', () {
    final route = Campaign.fromJson(_campaignJson()).route!;
    expect(route.skipped, isFalse);
    expect(route.stopIds, ['d-1', 'd-2']);
    expect(route.legs, hasLength(2));
    expect(route.legs.first.fromId, 'start');
    expect(route.legs.first.toId, 'd-1');
    expect(route.legs.first.duration, '300s');
    expect(route.hasGeometry, isFalse);
  });

  test('baseline and trace parse with labels', () {
    final campaign = Campaign.fromJson(_campaignJson());
    expect(campaign.baseline.ungrounded, isTrue);
    expect(campaign.baseline.venueNames, ['La Condesa', 'Suerte']);
    expect(campaign.trace, hasLength(2));
    expect(campaign.trace[0].stageLabel, 'Ungrounded baseline');
    expect(campaign.trace[0].cacheHit, isTrue);
    expect(campaign.trace[1].cursor, '2');
    expect(campaign.trace[1].stageLabel, 'Menu grounding');
    expect(campaign.trace[1].elapsedLabel, '1.5s');
  });

  test('ScoutJob accepts the running job shape and the campaign shape', () {
    final running = ScoutJob.fromJson({
      'job_id': 'run-0008',
      'campaign_id': 'cmp-austin-wholesale',
      'state': 'running',
      'trace_cursor': '4',
    });
    expect(running.state, JobState.running);
    expect(running.isRunning, isTrue);
    expect(running.hasCampaign, isFalse);
    expect(running.traceCursor, '4');

    final done = ScoutJob.fromJson(_campaignJson());
    expect(done.hasCampaign, isTrue);
    expect(done.state, JobState.ready);
    expect(done.traceCursor, '2');
    expect(done.campaign?.doors, hasLength(2));
  });

  test('unknown score terms stay explicitly unknown', () {
    final term = ScoreTerm.fromJson({'value': 0.4, 'source': 'qloo_fact'});
    expect(term.percent, 40);
    expect(term.isKnown, isTrue);

    const missing = ScoreTerm();
    expect(missing.isKnown, isFalse);
    expect(missing.displayText, 'Unknown');
  });
}
