import 'scout_models.dart';

/// One confirmed Qloo entity in a seed.
class SeedEntity {
  const SeedEntity({required this.id, required this.name, required this.type});

  final String id;
  final String name;

  /// The Qloo entity URN, for example `urn:entity:brand`.
  final String type;

  /// A readable entity kind for chips.
  String get kind {
    final tail = type.split(':').last;
    return tail.isEmpty ? 'entity' : tail;
  }

  factory SeedEntity.fromJson(Map<String, dynamic> json) => SeedEntity(
    id: (json['id'] ?? '').toString(),
    name: (json['name'] ?? '').toString(),
    type: (json['type'] ?? '').toString(),
  );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'type': type};
}

/// The request body for `POST /api/v1/scout`.
class ScoutRequest {
  const ScoutRequest({
    this.presetId,
    this.freeEntry = false,
    this.city = '',
    this.mode = ScoutMode.wholesale,
    this.radiusMeters = 8000,
    this.brandName = '',
    this.skus = const [],
    this.seedEntities = const [],
    this.brandQuery = '',
    this.fallbackQueries = const [],
    this.categoryTags = const [],
    this.point,
  });

  /// The locked preset id. When set, the gateway uses its stored point, seed,
  /// and category tags, so free-entry fields are ignored.
  final String? presetId;

  /// True when the operator built the seed by hand.
  final bool freeEntry;

  final String city;
  final ScoutMode mode;
  final int radiusMeters;
  final String brandName;
  final List<Sku> skus;
  final List<SeedEntity> seedEntities;

  /// A raw brand query for the live resolver. Use this when the operator typed
  /// a brand that is not in the confirmed catalogue.
  final String brandQuery;

  /// Raw vibe queries. The gateway resolves these through Qloo.
  final List<String> fallbackQueries;

  final List<String> categoryTags;

  /// A candidate point selected after an ambiguous city response.
  final GeoPoint? point;

  /// Builds a request for a locked preset.
  factory ScoutRequest.preset(String presetId) =>
      ScoutRequest(presetId: presetId, mode: ScoutMode.wholesale);

  /// Builds a free-entry request.
  factory ScoutRequest.freeEntry({
    required String city,
    required ScoutMode mode,
    required int radiusMeters,
    required String brandName,
    required List<Sku> skus,
    required List<SeedEntity> seedEntities,
    required String brandQuery,
    required List<String> fallbackQueries,
    required List<String> categoryTags,
    GeoPoint? point,
  }) => ScoutRequest(
    freeEntry: true,
    city: city,
    mode: mode,
    radiusMeters: radiusMeters,
    brandName: brandName,
    skus: skus,
    seedEntities: seedEntities,
    brandQuery: brandQuery,
    fallbackQueries: fallbackQueries,
    categoryTags: categoryTags,
    point: point,
  );

  /// Returns a copy with an explicit city point, used after the operator
  /// chooses an ambiguous geocode candidate.
  ScoutRequest copyWith({GeoPoint? point}) => ScoutRequest(
    presetId: presetId,
    freeEntry: freeEntry,
    city: city,
    mode: mode,
    radiusMeters: radiusMeters,
    brandName: brandName,
    skus: skus,
    seedEntities: seedEntities,
    brandQuery: brandQuery,
    fallbackQueries: fallbackQueries,
    categoryTags: categoryTags,
    point: point ?? this.point,
  );

  /// Serializes the gateway body. Empty optional fields are omitted so the
  /// gateway's idempotency hash stays stable across equivalent forms.
  Map<String, dynamic> toJson() {
    return {
      if (presetId != null && presetId!.isNotEmpty) 'preset_id': presetId,
      if (freeEntry) 'free_entry': true,
      if (city.trim().isNotEmpty) 'city': city.trim(),
      'mode': mode.name,
      if (radiusMeters > 0) 'radius_meters': radiusMeters,
      if (brandName.trim().isNotEmpty) 'brand_name': brandName.trim(),
      if (skus.isNotEmpty)
        'skus': skus
            .map((sku) => {'id': sku.id, 'name': sku.name})
            .toList(growable: false),
      if (seedEntities.isNotEmpty)
        'seed_entities': seedEntities
            .map((entity) => entity.toJson())
            .toList(growable: false),
      if (brandQuery.trim().isNotEmpty) 'brand_query': brandQuery.trim(),
      if (fallbackQueries.isNotEmpty)
        'fallback_queries': fallbackQueries
            .map((query) => query.trim())
            .where((query) => query.isNotEmpty)
            .toList(growable: false),
      if (categoryTags.isNotEmpty) 'category_tags': categoryTags,
      if (point != null) 'point': {'lat': point!.lat, 'lng': point!.lng},
    };
  }
}
