/// Models for the Karum scout, campaign, and trace payloads.
///
/// The gateway returns a compact job response while a scout is running and the
/// full campaign payload once it is terminal. [ScoutJob.fromJson] accepts both
/// shapes so a refresh can restore either state without branching in the UI.
library;

/// The three product modes.
enum ScoutMode {
  /// Which bars, cafés, and shops should carry the brand.
  wholesale,

  /// Which corridor or block should host a store or pop-up.
  flagship,

  /// Which non-competing boutiques should host an activation.
  collab;

  /// The short label used on mode pills and chips.
  String get label => switch (this) {
    ScoutMode.wholesale => 'Wholesale Doors',
    ScoutMode.flagship => 'Flagship & Pop-Up Scout',
    ScoutMode.collab => 'Brand Collabs',
  };

  /// The compact form used in headers and PDF actions.
  String get shortLabel => switch (this) {
    ScoutMode.wholesale => 'Wholesale',
    ScoutMode.flagship => 'Flagship',
    ScoutMode.collab => 'Collab',
  };

  /// Parses a gateway mode string, defaulting to wholesale.
  static ScoutMode parse(String? value) {
    return switch (value) {
      'flagship' => ScoutMode.flagship,
      'collab' => ScoutMode.collab,
      _ => ScoutMode.wholesale,
    };
  }
}

/// The job state reported by the gateway.
enum JobState {
  /// Seed and city are being resolved.
  resolving,

  /// The pipeline is running.
  running,

  /// The campaign is ready.
  ready,

  /// The campaign is ready with a stated fallback.
  degraded,

  /// The run failed; the error fields carry the detail.
  failed,

  /// The operator asked the gateway to abort.
  canceling,

  /// A state this client does not know yet.
  unknown;

  /// Parses a gateway state string.
  static JobState parse(String? value) {
    return switch (value) {
      'resolving' => JobState.resolving,
      'running' => JobState.running,
      'ready' => JobState.ready,
      'degraded' => JobState.degraded,
      'failed' => JobState.failed,
      'canceling' || 'cancelling' => JobState.canceling,
      _ => JobState.unknown,
    };
  }

  /// True once the gateway will not emit more trace events.
  bool get isTerminal =>
      this == JobState.ready ||
      this == JobState.degraded ||
      this == JobState.failed;

  /// The label shown in the workspace state chip.
  String get label => switch (this) {
    JobState.resolving => 'Resolving',
    JobState.running => 'Running',
    JobState.ready => 'Ready',
    JobState.degraded => 'Degraded',
    JobState.failed => 'Failed',
    JobState.canceling => 'Canceling',
    JobState.unknown => 'Unknown',
  };
}

/// A latitude/longitude pair.
class GeoPoint {
  const GeoPoint(this.lat, this.lng);

  /// Latitude in degrees.
  final double lat;

  /// Longitude in degrees.
  final double lng;

  /// True when both components are finite. Zero is valid, so this only rejects
  /// non-finite values.
  bool get isValid => lat.isFinite && lng.isFinite;

  /// Parses a point object.
  factory GeoPoint.fromJson(Map<String, dynamic> json) => GeoPoint(
    _double(json['lat']) ?? 0,
    _double(json['lng'] ?? json['lon']) ?? 0,
  );

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);

  @override
  String toString() => 'GeoPoint($lat, $lng)';
}

/// One product in the brand's own SKU list.
class Sku {
  const Sku({required this.id, required this.name});

  final String id;
  final String name;

  factory Sku.fromJson(Map<String, dynamic> json) =>
      Sku(id: _string(json['id']), name: _string(json['name']));

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

/// The brand context attached to a campaign.
class BrandContext {
  const BrandContext({required this.name, this.skus = const []});

  final String name;
  final List<Sku> skus;

  factory BrandContext.fromJson(Map<String, dynamic> json) => BrandContext(
    name: _string(json['name']),
    skus: _list(json['skus']).map(Sku.fromJson).toList(growable: false),
  );
}

/// A tag URN and its readable label.
class KarumTag {
  const KarumTag({required this.urn, required this.label});

  final String urn;
  final String label;

  factory KarumTag.fromJson(Map<String, dynamic> json) => KarumTag(
    urn: _string(json['urn']),
    label: _string(json['label']).isEmpty
        ? _labelFromUrn(_string(json['urn']))
        : _string(json['label']),
  );
}

/// One score term from the gateway.
class ScoreTerm {
  const ScoreTerm({
    this.value,
    this.display,
    this.raw,
    this.source = 'model_inference',
    this.inputs = const [],
  });

  /// The normalized 0-1 value.
  final double? value;

  /// The display value. Composite scores carry 0-100 here.
  final double? display;

  /// The raw upstream value, when the evidence panel should show it.
  final double? raw;

  /// `qloo_fact`, `model_inference`, `google_fact`, or a similar source.
  final String source;

  /// Query or explainability inputs recorded beside the score.
  final List<String> inputs;

  /// The percentage shown on a score bar.
  double? get percent {
    if (display != null) {
      return display!.clamp(0, 100).toDouble();
    }
    if (value != null) {
      return (value! * 100).clamp(0, 100).toDouble();
    }
    return null;
  }

  /// True when the gateway returned a usable value.
  bool get isKnown => percent != null;

  /// A human-readable score value.
  String get displayText {
    final p = percent;
    if (p == null) return 'Unknown';
    return '${p.round()}';
  }

  factory ScoreTerm.fromJson(Map<String, dynamic> json) => ScoreTerm(
    value: _double(json['value']),
    display: _double(json['display']),
    raw: _double(json['raw']),
    source: _string(json['source'], fallback: 'model_inference'),
    inputs: _stringList(json['inputs']),
  );
}

/// The four scores on one door.
class ScoreSet {
  const ScoreSet({
    this.culturalAffinity,
    this.shelfOpportunity,
    this.demographicAlignment,
    this.composite,
  });

  final ScoreTerm? culturalAffinity;
  final ScoreTerm? shelfOpportunity;
  final ScoreTerm? demographicAlignment;
  final ScoreTerm? composite;

  factory ScoreSet.fromJson(Map<String, dynamic> json) => ScoreSet(
    culturalAffinity: _score(json['cultural_affinity']),
    shelfOpportunity: _score(json['shelf_opportunity']),
    demographicAlignment: _score(json['demographic_alignment']),
    composite: _score(json['composite']),
  );
}

/// The Places read attached to one door.
class Enrichment {
  const Enrichment({
    this.address = '',
    this.hours = '',
    this.website = '',
    this.openStatus = 'unknown',
    this.unknown = false,
    this.lat,
    this.lng,
    this.attribution = '',
  });

  final String address;
  final String hours;
  final String website;
  final String openStatus;
  final bool unknown;
  final double? lat;
  final double? lng;
  final String attribution;

  bool get hasCoordinates =>
      lat != null && lng != null && lat!.isFinite && lng!.isFinite;

  String get openLabel {
    if (unknown) return 'Places data unavailable';
    return switch (openStatus) {
      'operational' => 'Open',
      'closed' => 'Closed',
      'closed_temporarily' => 'Temporarily closed',
      _ => 'Hours unverified',
    };
  }

  factory Enrichment.fromJson(Map<String, dynamic> json) => Enrichment(
    address: _string(json['address']),
    hours: _string(json['hours']),
    website: _string(json['website']),
    openStatus: _string(json['open_status'], fallback: 'unknown'),
    unknown: _bool(json['unknown']),
    lat: _double(json['lat']),
    lng: _double(json['lng']),
    attribution: _string(json['attribution']),
  );
}

/// One grounding citation. This is never a fetch target.
class SourceLink {
  const SourceLink({required this.url, required this.title});

  final String url;
  final String title;

  factory SourceLink.fromJson(Map<String, dynamic> json) => SourceLink(
    url: _string(json['url']),
    title: _string(json['title'], fallback: _string(json['url'])),
  );
}

/// One competitor found on a live menu or shelf.
class Incumbent {
  const Incumbent({required this.name, this.sources = const []});

  final String name;
  final List<SourceLink> sources;

  factory Incumbent.fromJson(Map<String, dynamic> json) => Incumbent(
    name: _string(json['name']),
    sources: _list(json['sources']).map(SourceLink.fromJson).toList(),
  );
}

/// The grounded menu/shelf read for one door.
class MenuFinding {
  const MenuFinding({
    this.summary = '',
    this.shelfUnknown = false,
    this.competitorCount = 0,
    this.incumbents = const [],
    this.sources = const [],
  });

  final String summary;
  final bool shelfUnknown;
  final int competitorCount;
  final List<Incumbent> incumbents;
  final List<SourceLink> sources;

  factory MenuFinding.fromJson(Map<String, dynamic> json) => MenuFinding(
    summary: _string(json['summary']),
    shelfUnknown: _bool(json['shelf_unknown']),
    competitorCount: _int(json['competitor_count']),
    incumbents: _list(json['incumbents']).map(Incumbent.fromJson).toList(),
    sources: _list(json['sources']).map(SourceLink.fromJson).toList(),
  );
}

/// The compare payload attached to a door.
class CompareChart {
  const CompareChart({
    required this.available,
    this.reason = '',
    this.tags = const [],
  });

  final bool available;
  final String reason;
  final List<KarumTag> tags;

  factory CompareChart.fromJson(Map<String, dynamic> json) => CompareChart(
    available: _bool(json['available']),
    reason: _string(json['reason']),
    tags: _list(json['tags']).map(KarumTag.fromJson).toList(),
  );
}

/// The displacement battlecard attached to a pitch.
class Battlecard {
  const Battlecard({
    required this.headline,
    this.incumbentName = '',
    this.talkingPoints = const [],
  });

  final String headline;
  final String incumbentName;
  final List<String> talkingPoints;

  factory Battlecard.fromJson(Map<String, dynamic> json) => Battlecard(
    headline: _string(json['headline']),
    incumbentName: _string(json['incumbent_name']),
    talkingPoints: _stringList(json['talking_points']),
  );
}

/// One generated door pitch.
class Pitch {
  const Pitch({
    required this.script,
    this.sku,
    this.battlecard,
    this.modeParagraph = '',
    this.template = false,
  });

  final String script;
  final Sku? sku;
  final Battlecard? battlecard;
  final String modeParagraph;

  /// True when the AI was unavailable and the gateway used its evidence-only
  /// template instead. The UI must label this rather than present it as a
  /// model-generated draft.
  final bool template;

  bool get isEmpty => script.trim().isEmpty;

  factory Pitch.fromJson(Map<String, dynamic> json) {
    final sku = json['sku'];
    return Pitch(
      script: _string(json['script']),
      sku: sku is Map ? Sku.fromJson(_map(sku)) : null,
      battlecard: json['battlecard'] is Map
          ? Battlecard.fromJson(_map(json['battlecard']))
          : null,
      modeParagraph: _string(json['mode_paragraph']),
      template: _bool(json['template']),
    );
  }
}

/// The recorded Qloo place block carried beside a door. These fields are facts
/// from the insights row, not a Google Places read (PLAN.md §34).
class QlooPlace {
  const QlooPlace({
    this.address = '',
    this.website = '',
    this.phone = '',
    this.hours = '',
    this.isClosed = false,
    this.lat,
    this.lng,
  });

  final String address;
  final String website;
  final String phone;
  final String hours;
  final bool isClosed;
  final double? lat;
  final double? lng;

  bool get hasCoordinates =>
      lat != null && lng != null && lat!.isFinite && lng!.isFinite;

  bool get isEmpty =>
      address.isEmpty &&
      website.isEmpty &&
      phone.isEmpty &&
      hours.isEmpty &&
      !isClosed &&
      !hasCoordinates;

  factory QlooPlace.fromJson(Map<String, dynamic> json) => QlooPlace(
    address: _string(json['address']),
    website: _string(json['website']),
    phone: _string(json['phone']),
    hours: _string(json['hours']),
    isClosed: _bool(json['is_closed']),
    lat: _double(json['lat']),
    lng: _double(json['lng']),
  );
}

/// One recommended door.
class Door {
  const Door({
    required this.id,
    required this.name,
    required this.rank,
    required this.scores,
    this.sharedTags = const [],
    this.place,
    this.enrichment,
    this.compare,
    this.pitch,
    this.menu,
    this.evidenceIds = const [],
  });

  final String id;
  final String name;
  final int rank;
  final ScoreSet scores;
  final List<KarumTag> sharedTags;
  final QlooPlace? place;
  final Enrichment? enrichment;
  final CompareChart? compare;
  final Pitch? pitch;
  final MenuFinding? menu;
  final List<String> evidenceIds;

  /// The composite percentage, or null when the gateway did not return one.
  double? get compositePercent => scores.composite?.percent;

  /// Coordinates from Places, falling back to the recorded Qloo place point.
  GeoPoint? get point {
    final e = enrichment;
    if (e != null && e.hasCoordinates) {
      return GeoPoint(e.lat!, e.lng!);
    }
    final recorded = place;
    if (recorded != null && recorded.hasCoordinates) {
      return GeoPoint(recorded.lat!, recorded.lng!);
    }
    return null;
  }

  factory Door.fromJson(Map<String, dynamic> json) => Door(
    id: _string(json['id']),
    name: _string(json['name']),
    rank: _int(json['rank']),
    scores: ScoreSet.fromJson(_map(json['scores'])),
    sharedTags: _list(json['shared_tags']).map(KarumTag.fromJson).toList(),
    place: json['place'] is Map
        ? QlooPlace.fromJson(_map(json['place']))
        : null,
    enrichment: json['enrichment'] is Map
        ? Enrichment.fromJson(_map(json['enrichment']))
        : null,
    compare: json['compare'] is Map
        ? CompareChart.fromJson(_map(json['compare']))
        : null,
    pitch: json['pitch'] is Map ? Pitch.fromJson(_map(json['pitch'])) : null,
    menu: json['menu'] is Map ? MenuFinding.fromJson(_map(json['menu'])) : null,
    evidenceIds: _stringList(json['evidence_ids']),
  );
}

/// One candidate the gateway placed on the skip list.
class SkipItem {
  const SkipItem({
    required this.id,
    required this.name,
    required this.reason,
    this.rawAffinity = 0,
    this.floor = 0,
    this.competitorCount = 0,
    this.lat,
    this.lng,
  });

  final String id;
  final String name;
  final String reason;
  final double rawAffinity;
  final double floor;
  final int competitorCount;
  final double? lat;
  final double? lng;

  /// The recorded Qloo point for this skip, when the row carried one.
  GeoPoint? get point {
    final latitude = lat;
    final longitude = lng;
    if (latitude == null || longitude == null) return null;
    if (!latitude.isFinite || !longitude.isFinite) return null;
    if (latitude == 0 && longitude == 0) return null;
    return GeoPoint(latitude, longitude);
  }

  /// Plain-English explanation for a machine-readable reason code.
  String get reasonLabel {
    return switch (reason) {
      'low_affinity' => 'Below the shortlist floor',
      'competitor_saturation' => 'Shelf already saturated',
      'closed' => 'Closed',
      'unresolved' => 'Could not resolve the venue',
      'outside_city' => 'Outside the city',
      'empty' => 'No doors matched',
      _ => _humanize(reason),
    };
  }

  factory SkipItem.fromJson(Map<String, dynamic> json) => SkipItem(
    id: _string(json['id']),
    name: _string(json['name']),
    reason: _string(json['reason'], fallback: 'low_affinity'),
    rawAffinity: _double(json['raw_affinity']) ?? 0,
    floor: _double(json['floor']) ?? 0,
    competitorCount: _int(json['competitor_count']),
    lat: _double(json['lat']),
    lng: _double(json['lng']),
  );
}

/// One evidence call recorded by the gateway.
class EvidenceCall {
  const EvidenceCall({
    required this.id,
    required this.endpoint,
    required this.resultCount,
    this.parameters = const [],
    this.source = 'qloo_fact',
  });

  final String id;
  final String endpoint;
  final List<String> parameters;
  final int resultCount;
  final String source;

  bool get isQlooFact => source == 'qloo_fact';

  factory EvidenceCall.fromJson(Map<String, dynamic> json) => EvidenceCall(
    id: _string(json['id']),
    endpoint: _string(json['endpoint']),
    parameters: _stringList(json['parameters']),
    resultCount: _int(json['result_count']),
    source: _string(json['source'], fallback: 'qloo_fact'),
  );
}

/// The generic-LLM counterfactual stored beside the Qloo result.
class Baseline {
  const Baseline({
    required this.text,
    this.ungrounded = true,
    this.venueNames = const [],
    this.errorCode = '',
  });

  final String text;
  final bool ungrounded;
  final List<String> venueNames;
  final String errorCode;

  bool get hasText => text.trim().isNotEmpty;

  factory Baseline.fromJson(Map<String, dynamic> json) => Baseline(
    text: _string(json['text']),
    ungrounded: _bool(json['ungrounded'], fallback: true),
    venueNames: _stringList(json['venue_names']),
    errorCode: _string(json['error_code']),
  );
}

/// One density cell in a flagship heatmap.
class HeatmapCell {
  const HeatmapCell({
    required this.point,
    this.affinity = 0,
    this.rank = 0,
    this.popularity = 0,
  });

  final GeoPoint point;
  final double affinity;
  final int rank;
  final double popularity;

  factory HeatmapCell.fromJson(Map<String, dynamic> json) => HeatmapCell(
    point: GeoPoint.fromJson(_map(json)),
    affinity: _double(json['affinity']) ?? 0,
    rank: _int(json['affinity_rank']),
    popularity: _double(json['popularity']) ?? 0,
  );
}

/// One locality boundary returned by the heatmap.
class LocalityPolygon {
  const LocalityPolygon({
    required this.name,
    this.affinity = 0,
    this.centroid,
    this.polygon = const [],
  });

  final String name;
  final double affinity;
  final GeoPoint? centroid;
  final List<GeoPoint> polygon;

  bool get hasPolygon => polygon.length >= 3;

  factory LocalityPolygon.fromJson(Map<String, dynamic> json) =>
      LocalityPolygon(
        name: _string(json['name']),
        affinity: _double(json['affinity']) ?? 0,
        centroid: json['centroid'] is Map
            ? GeoPoint.fromJson(_map(json['centroid']))
            : null,
        polygon: _list(json['polygon']).map(GeoPoint.fromJson).toList(),
      );
}

/// The flagship heatmap capability.
class Heatmap {
  const Heatmap({
    required this.available,
    this.reason = '',
    this.corridors = const [],
    this.anchors = const [],
    this.cells = const [],
    this.cellCount = 0,
    this.localityCount = 0,
    this.localities = const [],
  });

  final bool available;
  final String reason;
  final List<String> corridors;
  final List<String> anchors;
  final List<HeatmapCell> cells;
  final int cellCount;
  final int localityCount;
  final List<LocalityPolygon> localities;

  factory Heatmap.fromJson(Map<String, dynamic> json) => Heatmap(
    available: _bool(json['available']),
    reason: _string(json['reason']),
    corridors: _stringList(json['corridors']),
    anchors: _stringList(json['anchors']),
    cells: _list(json['cells']).map(HeatmapCell.fromJson).toList(),
    cellCount: _int(json['cell_count']),
    localityCount: _int(json['localities']),
    localities: _list(json['locality_polygons'])
        .map(LocalityPolygon.fromJson)
        .toList(),
  );
}

/// One hop of the field route.
class RouteLeg {
  const RouteLeg({
    required this.fromId,
    required this.toId,
    this.polyline = '',
    this.distanceMeters = 0,
    this.duration = '',
  });

  final String fromId;
  final String toId;
  final String polyline;
  final int distanceMeters;
  final String duration;

  factory RouteLeg.fromJson(Map<String, dynamic> json) => RouteLeg(
    fromId: _string(json['from_id']),
    toId: _string(json['to_id']),
    polyline: _string(json['polyline']),
    distanceMeters: _int(json['distance_meters']),
    duration: _string(json['duration']),
  );
}

/// The field route returned by the gateway.
class RoutePlan {
  const RoutePlan({
    required this.skipped,
    this.skipReason = '',
    this.failed = false,
    this.error = '',
    this.polyline = '',
    this.stopIds = const [],
    this.legs = const [],
    this.attribution = '',
  });

  final bool skipped;
  final String skipReason;
  final bool failed;
  final String error;
  final String polyline;
  final List<String> stopIds;
  final List<RouteLeg> legs;
  final String attribution;

  bool get hasGeometry =>
      polyline.isNotEmpty || legs.any((leg) => leg.polyline.isNotEmpty);

  factory RoutePlan.fromJson(Map<String, dynamic> json) => RoutePlan(
    skipped: _bool(json['skipped']),
    skipReason: _string(json['skip_reason']),
    failed: _bool(json['failed']),
    error: _string(json['error']),
    polyline: _string(json['polyline']),
    stopIds: _stringList(json['stop_ids']),
    legs: _list(json['legs']).map(RouteLeg.fromJson).toList(),
    attribution: _string(json['attribution']),
  );
}

/// One trace event.
class TraceEvent {
  const TraceEvent({
    required this.sequence,
    required this.stage,
    required this.elapsedMs,
    this.cursor = '',
    this.cacheHit = false,
    this.detail = '',
  });

  final int sequence;
  final String cursor;
  final String stage;
  final int elapsedMs;
  final bool cacheHit;
  final String detail;

  /// The plain-English stage name shown in the timeline.
  String get stageLabel {
    return switch (stage) {
      'seed_resolution' => 'Seed resolution',
      'scout' => 'Door ranking',
      'places' => 'Places enrichment',
      'menu_grounding' => 'Menu grounding',
      'draft' => 'Pitch drafting',
      'regenerate' => 'Pitch regeneration',
      'compare' => 'Audience compare',
      'heatmap' => 'Neighbourhood heatmap',
      'route' => 'Field route',
      'scoring' => 'Score assembly',
      'persist' => 'Campaign stored',
      'baseline' => 'Ungrounded baseline',
      _ => _humanize(stage),
    };
  }

  /// Elapsed time as seconds with one decimal below ten seconds.
  String get elapsedLabel {
    final seconds = elapsedMs / 1000;
    return seconds < 10
        ? '${seconds.toStringAsFixed(1)}s'
        : '${seconds.round()}s';
  }

  factory TraceEvent.fromJson(Map<String, dynamic> json) => TraceEvent(
    sequence: _int(json['sequence']),
    cursor: _string(json['cursor']),
    stage: _string(json['stage']),
    elapsedMs: _int(json['elapsed_ms']),
    cacheHit: _bool(json['cache_hit']),
    detail: _string(json['detail']),
  );
}

/// The full campaign payload.
class Campaign {
  const Campaign({
    required this.jobId,
    required this.state,
    required this.mode,
    required this.city,
    required this.brand,
    this.campaignId = '',
    this.point,
    this.pointAttribution = '',
    this.radiusMeters = 0,
    this.formula = '',
    this.doors = const [],
    this.skipList = const [],
    this.evidence = const [],
    this.baseline = const Baseline(text: ''),
    this.heatmap,
    this.route,
    this.warnings = const [],
    this.trace = const [],
    this.errorCode = '',
    this.errorMessage = '',
  });

  final String jobId;
  final String campaignId;
  final JobState state;
  final ScoutMode mode;
  final String city;
  final GeoPoint? point;
  final String pointAttribution;
  final int radiusMeters;
  final BrandContext brand;
  final String formula;
  final List<Door> doors;
  final List<SkipItem> skipList;
  final List<EvidenceCall> evidence;
  final Baseline baseline;
  final Heatmap? heatmap;
  final RoutePlan? route;
  final List<String> warnings;
  final List<TraceEvent> trace;
  final String errorCode;
  final String errorMessage;

  /// The first recommended door, or null when the board is empty.
  Door? get firstDoor => doors.isEmpty ? null : doors.first;

  /// True when the run produced no recommended doors.
  bool get isEmpty => doors.isEmpty;

  /// The score formula, falling back to the canonical expression.
  String get formulaText => formula.trim().isEmpty
      ? 'S_door = 0.50 · A_taste + 0.30 · O_shelf + 0.20 · D_demo'
      : formula;

  /// Finds a door by id without re-sorting.
  Door? doorById(String id) {
    for (final door in doors) {
      if (door.id == id) return door;
    }
    return null;
  }

  /// The evidence call for an id, when present.
  EvidenceCall? evidenceById(String id) {
    for (final call in evidence) {
      if (call.id == id) return call;
    }
    return null;
  }

  factory Campaign.fromJson(Map<String, dynamic> json) {
    final brandJson = json['brand'];
    return Campaign(
      jobId: _string(json['job_id']),
      campaignId: _string(json['campaign_id']),
      state: JobState.parse(_string(json['state'], fallback: 'ready')),
      mode: ScoutMode.parse(_string(json['mode'])),
      city: _string(json['city']),
      point: json['point'] is Map
          ? GeoPoint.fromJson(_map(json['point']))
          : null,
      pointAttribution: _string(json['point_attribution']),
      radiusMeters: _int(json['radius_meters']),
      brand: brandJson is Map
          ? BrandContext.fromJson(_map(brandJson))
          : const BrandContext(name: ''),
      formula: _string(json['formula']),
      doors: _list(json['doors']).map(Door.fromJson).toList(),
      skipList: _list(json['skip_list']).map(SkipItem.fromJson).toList(),
      evidence: _list(json['evidence']).map(EvidenceCall.fromJson).toList(),
      baseline: json['baseline'] is Map
          ? Baseline.fromJson(_map(json['baseline']))
          : const Baseline(text: ''),
      heatmap: json['heatmap'] is Map
          ? Heatmap.fromJson(_map(json['heatmap']))
          : null,
      route: json['route'] is Map
          ? RoutePlan.fromJson(_map(json['route']))
          : null,
      warnings: _stringList(json['warnings']),
      trace: _list(json['trace']).map(TraceEvent.fromJson).toList(),
      errorCode: _string(json['error_code']),
      errorMessage: _string(json['error_message']),
    );
  }
}

/// A job response, with the campaign when the job is terminal.
class ScoutJob {
  const ScoutJob({
    required this.jobId,
    required this.state,
    this.campaignId = '',
    this.traceCursor = '',
    this.errorCode = '',
    this.errorMessage = '',
    this.campaign,
  });

  final String jobId;
  final String campaignId;
  final JobState state;
  final String traceCursor;
  final String errorCode;
  final String errorMessage;
  final Campaign? campaign;

  /// True when the response carried the full campaign.
  bool get hasCampaign => campaign != null;

  /// True while the gateway may still emit trace events.
  bool get isRunning =>
      state == JobState.resolving ||
      state == JobState.running ||
      state == JobState.canceling;

  /// Parses either the compact job shape or the full campaign shape.
  factory ScoutJob.fromJson(Map<String, dynamic> json) {
    final hasCampaignShape =
        json.containsKey('doors') ||
        json.containsKey('mode') ||
        json.containsKey('brand');
    final state = JobState.parse(_string(json['state']));
    if (hasCampaignShape) {
      final campaign = Campaign.fromJson(json);
      return ScoutJob(
        jobId: campaign.jobId,
        campaignId: campaign.campaignId,
        state: campaign.state,
        traceCursor: campaign.trace.isEmpty ? '' : campaign.trace.last.cursor,
        errorCode: campaign.errorCode,
        errorMessage: campaign.errorMessage,
        campaign: campaign,
      );
    }
    return ScoutJob(
      jobId: _string(json['job_id']),
      campaignId: _string(json['campaign_id']),
      state: state,
      traceCursor: _string(json['trace_cursor']),
      errorCode: _string(json['error_code']),
      errorMessage: _string(json['error_message']),
    );
  }
}

// ---------------------------------------------------------------------------
// Parsing helpers. The gateway is the system of record, so a malformed leaf
// should degrade to an empty value rather than take down an entire board.
// ---------------------------------------------------------------------------

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const {};
}

List<Map<String, dynamic>> _list(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => item.map((key, v) => MapEntry(key.toString(), v)))
      .toList(growable: false);
}

ScoreTerm? _score(Object? value) {
  if (value is! Map) return null;
  return ScoreTerm.fromJson(_map(value));
}

double? _double(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

int _int(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

bool _bool(Object? value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) return value.toLowerCase() == 'true';
  return fallback;
}

String _string(Object? value, {String fallback = ''}) {
  if (value is String) return value;
  if (value == null) return fallback;
  return value.toString();
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value
      .where((item) => item != null)
      .map((item) => item.toString())
      .toList(growable: false);
}

String _humanize(String value) {
  final cleaned = value.replaceAll('_', ' ').trim();
  if (cleaned.isEmpty) return 'Event';
  return cleaned[0].toUpperCase() + cleaned.substring(1);
}

String _labelFromUrn(String urn) {
  if (urn.isEmpty) return '';
  final tail = urn.split(':').last.replaceAll('_', ' ');
  if (tail.isEmpty) return urn;
  return tail[0].toUpperCase() + tail.substring(1);
}
