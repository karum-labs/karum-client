import '../api/scout_models.dart';
import '../api/scout_request.dart';

/// One locked demo preset.
///
/// The catalogue (this class's data) is fetched from `GET /api/v1/presets`
/// at startup — see [GatewayClient.fetchPresets] and [PresetCatalog.fromJson]
/// — not hand-duplicated in this file. The four presets the gateway serves
/// are its own `internal/presets` package (PLAN.md §52); this class only
/// shapes that response for the widgets that render it.
class KarumPreset {
  const KarumPreset({
    required this.id,
    required this.groupId,
    required this.groupLabel,
    required this.groupDescription,
    required this.label,
    required this.buttonLabel,
    required this.brand,
    required this.city,
    required this.mode,
    required this.description,
    required this.seeds,
    required this.skus,
    required this.categoryTags,
    this.radiusMeters = 8000,
    this.point,
    this.campaignId = '',
  });

  final String id;

  /// Ties variants that share one landing card (Brooklyn's flagship and
  /// collab buttons both carry `groupId == 'brooklyn'`).
  final String groupId;

  /// The card heading and subtitle, repeated on every variant in the group.
  final String groupLabel;
  final String groupDescription;

  final String label;
  final String buttonLabel;
  final String brand;
  final String city;
  final ScoutMode mode;
  final String description;
  final List<SeedEntity> seeds;
  final List<Sku> skus;
  final List<String> categoryTags;
  final int radiusMeters;

  /// The preset's stored city point. "Inspect this seed" hands it to the
  /// free-entry form so the previous run still works when no geocoder key is set.
  final GeoPoint? point;

  /// The campaign id the gateway seeds for this preset, as the server sent
  /// it — not reconstructed client-side, so a server-side id scheme change
  /// cannot silently desync the two.
  final String campaignId;

  factory KarumPreset.fromJson(Map<String, dynamic> json) {
    final rawPoint = json['point'];
    GeoPoint? point;
    if (rawPoint is Map) {
      point = GeoPoint.fromJson(
        rawPoint.map((k, v) => MapEntry(k.toString(), v)),
      );
    }
    return KarumPreset(
      id: (json['id'] ?? '').toString(),
      groupId: (json['group_id'] ?? '').toString(),
      groupLabel: (json['group_label'] ?? '').toString(),
      groupDescription: (json['group_description'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      buttonLabel: (json['button_label'] ?? '').toString(),
      brand: (json['brand'] ?? '').toString(),
      city: (json['city'] ?? '').toString(),
      mode: ScoutMode.parse(json['mode']?.toString()),
      description: (json['description'] ?? '').toString(),
      seeds: ((json['seeds'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (e) =>
                SeedEntity.fromJson(e.map((k, v) => MapEntry(k.toString(), v))),
          )
          .toList(growable: false),
      skus: ((json['skus'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => Sku.fromJson(e.map((k, v) => MapEntry(k.toString(), v))))
          .toList(growable: false),
      categoryTags: ((json['category_tags'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      radiusMeters: (json['radius_meters'] is num)
          ? (json['radius_meters'] as num).toInt()
          : 8000,
      point: point,
      campaignId: (json['campaign_id'] ?? '').toString(),
    );
  }
}

/// One card on the landing screen. Brooklyn carries two mode variants behind a
/// single card, matching the judge script's flagship/collab toggle. Built by
/// grouping the flat preset list on [KarumPreset.groupId].
class PresetGroup {
  const PresetGroup({
    required this.name,
    required this.city,
    required this.brand,
    required this.description,
    required this.variants,
  });

  final String name;
  final String city;
  final String brand;
  final String description;
  final List<KarumPreset> variants;
}

/// A company or reference entity the seed builder can suggest without a
/// network round trip.
class KnownSeed {
  const KnownSeed({
    required this.entity,
    required this.city,
    required this.sourcePreset,
  });

  final SeedEntity entity;
  final String city;
  final String sourcePreset;

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.length < 2) return false;
    return entity.name.toLowerCase().contains(q);
  }
}

/// A category chip the seed builder can send as a Qloo tag filter.
class CategoryTagOption {
  const CategoryTagOption({required this.label, required this.urn});

  final String label;
  final String urn;
}

/// The locked preset catalogue, built from the gateway's `GET
/// /api/v1/presets` response.
///
/// This replaces a set of hand-duplicated Dart constants that used to mirror
/// `karum-server/internal/presets`: the client now has one source of truth
/// for this data (brand names, Qloo seed entity ids, SKUs) instead of
/// a copy that could silently drift from the server's (PLAN.md §52).
class PresetCatalog {
  const PresetCatalog({
    required this.all,
    required this.groups,
    required this.knownSeeds,
  });

  /// The presets in server order.
  final List<KarumPreset> all;

  /// The cards the landing screen renders.
  final List<PresetGroup> groups;

  /// Every confirmed entity the typeahead can suggest locally. The gateway
  /// currently exposes no seed-resolution endpoint; a typed query is sent as
  /// `brand_query` instead of being invented as an entity id.
  final List<KnownSeed> knownSeeds;

  /// Category chips verified by the fixture pack. Not preset-specific data —
  /// these are the seed builder's free-entry tag options, so they stay a
  /// client-side constant rather than part of the fetched catalogue.
  static const List<CategoryTagOption> categoryTags = [
    CategoryTagOption(
      label: 'Bars & restaurants',
      urn: 'urn:tag:genre:place:restaurant:bar',
    ),
    CategoryTagOption(
      label: 'Cafés',
      urn: 'urn:tag:genre:place:restaurant:cafe',
    ),
    CategoryTagOption(
      label: 'Galleries',
      urn: 'urn:tag:genre:place:art_gallery',
    ),
    CategoryTagOption(label: 'Ceramics', urn: 'urn:tag:genre:place:ceramics'),
  ];

  /// Parses `GET /api/v1/presets`' `{"presets": [...]}` body.
  factory PresetCatalog.fromJson(Map<String, dynamic> json) {
    final items = ((json['presets'] as List?) ?? const [])
        .whereType<Map>()
        .map(
          (e) =>
              KarumPreset.fromJson(e.map((k, v) => MapEntry(k.toString(), v))),
        )
        .toList(growable: false);
    return PresetCatalog.fromPresets(items);
  }

  /// Groups a flat preset list by `groupId`, preserving first-seen order —
  /// the server lists Brooklyn's flagship variant before its collab variant,
  /// so the card keeps that button order.
  factory PresetCatalog.fromPresets(List<KarumPreset> items) {
    final groups = <String, List<KarumPreset>>{};
    final order = <String>[];
    for (final item in items) {
      final key = item.groupId.isEmpty ? item.id : item.groupId;
      if (!groups.containsKey(key)) order.add(key);
      groups.putIfAbsent(key, () => []).add(item);
    }
    final builtGroups = [
      for (final key in order)
        PresetGroup(
          name: groups[key]!.first.groupLabel,
          city: groups[key]!.first.city.split(',').first.trim(),
          brand: groups[key]!.first.brand,
          description: groups[key]!.first.groupDescription,
          variants: groups[key]!,
        ),
    ];
    final knownSeeds = _dedupeKnownSeeds([
      for (final preset in items)
        for (final seed in preset.seeds)
          KnownSeed(
            entity: seed,
            city: preset.city,
            sourcePreset: preset.label,
          ),
    ]);
    return PresetCatalog(
      all: items,
      groups: builtGroups,
      knownSeeds: knownSeeds,
    );
  }

  /// Looks up a variant by id.
  KarumPreset? byId(String id) {
    for (final preset in all) {
      if (preset.id == id) return preset;
    }
    return null;
  }

  static List<KnownSeed> _dedupeKnownSeeds(List<KnownSeed> input) {
    final seen = <String>{};
    final out = <KnownSeed>[];
    for (final item in input) {
      if (seen.add(item.entity.id)) out.add(item);
    }
    return List.unmodifiable(out);
  }
}
