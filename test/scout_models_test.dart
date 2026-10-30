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
        'hours': 'Monday: 4 PM–2 AM',
        'website': 'https://example.com/whislers',
        'open_status': 'operational',
        'unknown': false,
        'lat': 30.2672,
        'lng': -97.7431,
        'attribution': 'Map data © Google',
      },
      'pitch': {
        'script': 'Whisler\'s ranks first of 25.\nGood morning.',
        'opening': 'Good morning.',
        'why_this_door': "Whisler's ranks first of 25.",
        'pitch': 'Take the Espadín Joven on a six-bottle trial.',
        'product_to_lead': 'Espadín Joven',
        'ask': 'Will you stock it?',
        'close': 'Thanks for your time.',
        'sku': {'id': 'sk-espadin', 'name': 'Espadín Joven'},
        'battlecard': {
          'headline': 'Mezcal shelf is undifferentiated',
          'incumbent_name': 'Del Maguey',
          'talking_points': ['Only two mezcals on the back bar'],
        },
        'mode_paragraph': 'Wholesale placement wins on bottle-share.',
        'template': true,
        'sources': [
          {'evidence_id': 'ev-0001', 'text': 'Whisler\'s ranks first of 25 doors'},
        ],
      },
      'menu': {
        'summary': 'Two mezcal competitors on the list.',
        'shelf_unknown': true,
        'competitor_count': 2,
        'incumbents': [
          {
            'name': 'Del Maguey',
            'sources': [
              {'url': 'https://example.com/menu', 'title': 'Spring 2026 menu'},
            ],
          },
        ],
        'sources': [
          {'url': 'https://example.com/list'},
        ],
      },
      'evidence_ids': ['ev-0001'],
      'explainability': [
        {'entity_id': 'e-1', 'label': 'Ilegal Mezcal', 'score': 0.62},
      ],
      'demographics': {
        'age_buckets': [
          {'label': '25_34', 'delta': 0.12},
        ],
        'male_delta': 0.03,
        'female_delta': -0.04,
      },
      'distance_meters': 820,
    },
    {
      'id': 'd-2',
      'name': 'Here Nor There',
      'rank': 2,
      'scores': {
        'cultural_affinity': {'value': 0.64, 'source': 'model_inference'},
      },
      'shared_tags': [],
      'enrichment': {'open_status': 'unknown', 'unknown': true},
      'place': {
        'address': '801 W 6th St, Austin, TX',
        'website': 'https://example.com/here-nor-there',
        'hours': 'Tue 17:00-00:00',
        'phone': '+1 512 555 0199',
        'lat': 30.271,
        'lng': -97.7501,
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
      'lat': 30.2676,
      'lng': -97.7387,
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
    'locality_polygons': [
      {
        'name': 'East Austin',
        'affinity': 0.8,
        'centroid': {'lat': 30.262, 'lng': -97.727},
        'polygon': [
          {'lat': 30.25, 'lng': -97.74},
          {'lat': 30.27, 'lng': -97.74},
          {'lat': 30.27, 'lng': -97.71},
        ],
      },
    ],
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
    expect(door.scores.composite?.partial, isFalse);
    expect(door.scores.demographicAlignment, isNull);
  });

  test('a renormalized composite carries its partial flag', () {
    final term = ScoreTerm.fromJson({
      'value': 1,
      'display': 100,
      'source': 'model_inference',
      'partial': true,
    });

    expect(term.partial, isTrue);
    expect(term.displayText, '100');
  });

  test('door coordinates prefer Places, then the recorded Qloo point', () {
    final campaign = Campaign.fromJson(_campaignJson());
    expect(campaign.doors[0].point, const GeoPoint(30.2672, -97.7431));
    expect(campaign.doors[0].enrichment?.openLabel, 'Open');
    expect(campaign.doors[1].point, const GeoPoint(30.271, -97.7501));
    expect(campaign.doors[1].place?.address, '801 W 6th St, Austin, TX');
    expect(campaign.doors[1].enrichment?.openLabel, 'Places data unavailable');
  });

  test('menu findings and citations parse', () {
    final menu = Campaign.fromJson(_campaignJson()).doors.first.menu!;
    expect(menu.summary, 'Two mezcal competitors on the list.');
    expect(menu.shelfUnknown, isTrue);
    expect(menu.competitorCount, 2);
    expect(menu.incumbents.single.name, 'Del Maguey');
    expect(
      menu.incumbents.single.sources.single.url,
      'https://example.com/menu',
    );
    expect(menu.incumbents.single.sources.single.title, 'Spring 2026 menu');
    // A title-less source falls back to its URL.
    expect(menu.sources.single.title, 'https://example.com/list');
  });

  test('pitch keeps the template flag and battlecard', () {
    final pitch = Campaign.fromJson(_campaignJson()).doors.first.pitch!;
    expect(pitch.template, isTrue);
    expect(pitch.sku?.name, 'Espadín Joven');
    expect(pitch.battlecard?.incumbentName, 'Del Maguey');
    expect(
      pitch.battlecard?.talkingPoints.single,
      'Only two mezcals on the back bar',
    );
    expect(pitch.isEmpty, isFalse);
  });

  test('pitch sections and sources parse from JSON', () {
    final pitch = Campaign.fromJson(_campaignJson()).doors.first.pitch!;
    expect(pitch.opening, 'Good morning.');
    expect(pitch.whyThisDoor, "Whisler's ranks first of 25.");
    expect(pitch.pitchSection, 'Take the Espadín Joven on a six-bottle trial.');
    expect(pitch.productToLead, 'Espadín Joven');
    expect(pitch.ask, 'Will you stock it?');
    expect(pitch.close, 'Thanks for your time.');
    expect(
      pitch.sources,
      [Citation(evidenceId: 'ev-0001', text: "Whisler's ranks first of 25 doors")],
    );
  });

  test('pitch prose carries no inline citation tokens', () {
    final pitch = Campaign.fromJson(_campaignJson()).doors.first.pitch!;
    for (final text in [
      pitch.script,
      pitch.opening,
      pitch.whyThisDoor,
      pitch.pitchSection,
      pitch.productToLead,
      pitch.ask,
      pitch.close,
    ]) {
      expect(RegExp(r'ev-\d+').hasMatch(text), isFalse, reason: text);
    }
  });

  test('skip reasons map to plain English', () {
    final skip = Campaign.fromJson(_campaignJson()).skipList.single;
    expect(skip.reason, 'competitor_saturation');
    expect(skip.reasonLabel, 'Shelf already saturated');
    expect(skip.floor, 0.3);
    expect(skip.competitorCount, 6);
    expect(skip.point, const GeoPoint(30.2676, -97.7387));
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
    final locality = heatmap.localities.single;
    expect(locality.name, 'East Austin');
    expect(locality.hasPolygon, isTrue);
    expect(locality.centroid, const GeoPoint(30.262, -97.727));
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

  test(
    'the Qloo evidence a door carries parses, and its absence stays absent',
    () {
      final doors = Campaign.fromJson(_campaignJson()).doors;

      final first = doors.first;
      expect(first.explainability.single.entityId, 'e-1');
      expect(first.explainability.single.label, 'Ilegal Mezcal');
      expect(first.explainability.single.score, 0.62);
      expect(first.demographics!.ageBuckets.single.label, '25_34');
      expect(first.demographics!.ageBuckets.single.delta, 0.12);
      expect(first.demographics!.maleDelta, 0.03);
      expect(first.demographics!.femaleDelta, -0.04);
      expect(first.distanceMeters, 820);

      // A door the gateway carried no evidence for stays empty, never zeroed.
      final second = doors[1];
      expect(second.explainability, isEmpty);
      expect(second.demographics, isNull);
      expect(second.distanceMeters, 0);
    },
  );

  test('unknown score terms stay explicitly unknown', () {
    final term = ScoreTerm.fromJson({'value': 0.4, 'source': 'qloo_fact'});
    expect(term.percent, 40);
    expect(term.isKnown, isTrue);

    const missing = ScoreTerm();
    expect(missing.isKnown, isFalse);
    expect(missing.displayText, 'Unknown');
  });
}
