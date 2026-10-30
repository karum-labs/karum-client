import 'scout_models.dart';

/// The signed-in account's brand: what it is and why a venue should stock
/// it. Door pitches are written for this brand.
class BrandProfile {
  const BrandProfile({
    this.name = '',
    this.category = '',
    this.description = '',
    this.positioning = '',
    this.audience = '',
    this.skus = const [],
    this.saved = false,
  });

  final String name;
  final String category;
  final String description;
  final String positioning;
  final String audience;
  final List<Sku> skus;

  /// False until the account has saved a profile.
  final bool saved;

  factory BrandProfile.fromJson(
    Map<String, dynamic> json, {
    bool saved = false,
  }) {
    String text(Object? value) => value is String ? value : '';
    final rawSkus = json['skus'];
    return BrandProfile(
      name: text(json['name']),
      category: text(json['category']),
      description: text(json['description']),
      positioning: text(json['positioning']),
      audience: text(json['audience']),
      skus: rawSkus is List
          ? rawSkus
                .whereType<Map>()
                .map(
                  (e) => Sku.fromJson(
                    e.map((key, value) => MapEntry(key.toString(), value)),
                  ),
                )
                .toList(growable: false)
          : const [],
      saved: saved,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'category': category,
    'description': description,
    'positioning': positioning,
    'audience': audience,
    'skus': skus.map((sku) => sku.toJson()).toList(growable: false),
  };
}
