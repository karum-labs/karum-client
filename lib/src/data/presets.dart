import '../api/scout_models.dart';
import '../api/scout_request.dart';

/// One locked demo preset.
class KarumPreset {
  const KarumPreset({
    required this.id,
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
  });

  final String id;
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
  /// free-entry form so the sample still runs when no geocoder key is set.
  final GeoPoint? point;
}

/// One card on the landing screen. Brooklyn carries two mode variants behind a
/// single card, matching the judge script's flagship/collab toggle.
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

/// The locked preset catalogue, mirroring `karum-server/internal/presets`.
abstract final class PresetCatalog {
  static const List<SeedEntity> _austinSeeds = [
    SeedEntity(
      id: '32F867B9-E6DF-44C3-BCE4-40160C7ED5E4',
      name: 'Aesop',
      type: 'urn:entity:brand',
    ),
    SeedEntity(
      id: '41C4BB40-E667-416F-9541-63FD7E7FFFF5',
      name: 'Ilegal Mezcal',
      type: 'urn:entity:brand',
    ),
    SeedEntity(
      id: 'BAF6317A-DF94-4C90-92AE-63F86560C21B',
      name: 'Khruangbin',
      type: 'urn:entity:artist',
    ),
  ];

  static const List<SeedEntity> _brooklynSeeds = [
    SeedEntity(
      id: 'E12201A5-CC50-40AF-97AE-C54A2CA303F7',
      name: 'Muji',
      type: 'urn:entity:brand',
    ),
    SeedEntity(
      id: '2B5888A0-8A41-4F23-9E1E-0F52DA29244A',
      name: 'Choplet Ceramic Studio & Gallery',
      type: 'urn:entity:place',
    ),
    SeedEntity(
      id: '6E449EFE-6006-4023-8EEC-0F1F720BDC94',
      name: 'BKLYN CLAY',
      type: 'urn:entity:place',
    ),
    SeedEntity(
      id: '98F7EBDF-987C-4741-B6F8-5C7511DC0021',
      name: 'Kettl Tea',
      type: 'urn:entity:place',
    ),
  ];

  static const List<SeedEntity> _colabaSeeds = [
    SeedEntity(
      id: '0DE2E903-CCB5-4523-BAF0-3EC15514248C',
      name: 'Mary Lodge by Subko',
      type: 'urn:entity:place',
    ),
    SeedEntity(
      id: '6CEDF620-266F-4B72-B14E-875532C321B1',
      name: 'Blue Tokai Coffee Roasters | Bandra',
      type: 'urn:entity:place',
    ),
    SeedEntity(
      id: '617683A6-DCF8-4104-8A1A-7484D1F9601C',
      name: 'Blue Tokai Coffee Roasters | Versova',
      type: 'urn:entity:place',
    ),
  ];

  static const KarumPreset austin = KarumPreset(
    id: 'austin-wholesale',
    label: 'Sola in Austin',
    buttonLabel: 'Try Sample: Sola Yuzu Mezcal in Austin, TX',
    brand: 'Sola',
    city: 'Austin, TX, US',
    mode: ScoutMode.wholesale,
    description: 'Mezcal aperitif · bars and restaurants',
    seeds: _austinSeeds,
    skus: [
      Sku(id: 'sola-aperitif', name: 'Sola Yuzu-Mezcal Aperitif'),
      Sku(id: 'sola-spritz', name: 'Sola Mezcal Spritz'),
    ],
    categoryTags: ['urn:tag:genre:place:restaurant:bar'],
    // The doors were captured at 8 km. Every preset pins its radius so the
    // mirror cannot silently fall back to the default.
    radiusMeters: 8000,
    point: GeoPoint(30.2672, -97.7431),
  );

  static const KarumPreset brooklynFlagship = KarumPreset(
    id: 'brooklyn-flagship',
    label: 'Ceramics and matcha in Brooklyn',
    buttonLabel: 'Try Sample: Ceramics & Matcha — Flagship',
    brand: 'Muji',
    city: 'Brooklyn, NY, US',
    mode: ScoutMode.flagship,
    description:
        'Design retail, ceramics studios, and matcha · corridor heatmap',
    seeds: _brooklynSeeds,
    skus: [
      Sku(id: 'muji-ceramics', name: 'Muji Ceramic Tableware'),
      Sku(id: 'muji-matcha', name: 'Muji Matcha Bowl'),
      Sku(id: 'muji-linen', name: 'Muji Linen Apron'),
    ],
    categoryTags: ['urn:tag:genre:place:restaurant:cafe'],
    // The doors were captured at 8 km; 10 km is the corridor heatmap's radius.
    // "Inspect this seed" must reproduce the preset, not widen it.
    radiusMeters: 8000,
    point: GeoPoint(40.7172, -73.9566),
  );

  static const KarumPreset brooklynCollab = KarumPreset(
    id: 'brooklyn-collab',
    label: 'Brooklyn collab',
    buttonLabel: 'Try Sample: Ceramics & Matcha — Collab',
    brand: 'Muji',
    city: 'Brooklyn, NY, US',
    mode: ScoutMode.collab,
    description: 'Galleries and ceramics studios · activation partners',
    seeds: _brooklynSeeds,
    skus: [
      Sku(id: 'muji-ceramics', name: 'Muji Ceramic Tableware'),
      Sku(id: 'muji-matcha', name: 'Muji Matcha Bowl'),
      Sku(id: 'muji-linen', name: 'Muji Linen Apron'),
    ],
    categoryTags: [
      'urn:tag:genre:place:art_gallery',
      'urn:tag:genre:place:ceramics',
    ],
    radiusMeters: 8000,
    point: GeoPoint(40.7172, -73.9566),
  );

  static const KarumPreset colaba = KarumPreset(
    id: 'mumbai-colaba-wholesale',
    label: 'Cacao and coffee in Colaba',
    buttonLabel: 'Try Sample: Cacao & Coffee in Colaba, Mumbai',
    brand: 'Subko',
    city: 'Mumbai, MH, IN',
    mode: ScoutMode.wholesale,
    description: 'Specialty cacao and coffee · cafés',
    seeds: _colabaSeeds,
    skus: [
      Sku(id: 'subko-cacao', name: 'Subko Specialty Cacao'),
      Sku(id: 'subko-coffee', name: 'Subko Single-Origin Coffee'),
    ],
    categoryTags: ['urn:tag:genre:place:restaurant:cafe'],
    radiusMeters: 8000,
    point: GeoPoint(18.93, 72.83),
  );

  /// The four variants in server order.
  static const List<KarumPreset> all = [
    austin,
    brooklynFlagship,
    brooklynCollab,
    colaba,
  ];

  /// The three cards the landing screen renders.
  static const List<PresetGroup> groups = [
    PresetGroup(
      name: 'Sola in Austin',
      city: 'Austin, TX',
      brand: 'Sola',
      description: 'A mezcal aperitif with no Qloo brand entity. The seed swaps in verified substitutes.',
      variants: [austin],
    ),
    PresetGroup(
      name: 'Ceramics and matcha in Brooklyn',
      city: 'Brooklyn, NY',
      brand: 'Muji',
      description: 'One seed, two questions: where to open, and who to collaborate with.',
      variants: [brooklynFlagship, brooklynCollab],
    ),
    PresetGroup(
      name: 'Cacao and coffee in Colaba',
      city: 'Mumbai, IN',
      brand: 'Subko',
      description: 'Brand-typed search misses; the seed resolves Mumbai specialty cafés.',
      variants: [colaba],
    ),
  ];

  /// Looks up a variant by id.
  static KarumPreset? byId(String id) {
    for (final preset in all) {
      if (preset.id == id) return preset;
    }
    return null;
  }

  /// Every confirmed entity the typeahead can suggest locally. The gateway
  /// currently exposes no seed-resolution endpoint; a typed query is sent as
  /// `brand_query` instead of being invented as an entity id.
  static final List<KnownSeed> knownSeeds = _dedupeKnownSeeds([
    for (final preset in all)
      for (final seed in preset.seeds)
        KnownSeed(entity: seed, city: preset.city, sourcePreset: preset.label),
  ]);

  /// Category chips verified by the fixture pack.
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

  static List<KnownSeed> _dedupeKnownSeeds(List<KnownSeed> input) {
    final seen = <String>{};
    final out = <KnownSeed>[];
    for (final item in input) {
      if (seen.add(item.entity.id)) out.add(item);
    }
    return List.unmodifiable(out);
  }
}
