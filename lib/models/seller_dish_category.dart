import '../config/optica2_asset_url.dart';

/// Menu sub category under a dish category (e.g. Chicken Biryani).
class SellerDishSubcategory {
  const SellerDishSubcategory({
    required this.id,
    required this.name,
    this.slug,
    this.imageUrl,
  });

  final int id;
  final String name;
  final String? slug;
  final String? imageUrl;

  factory SellerDishSubcategory.fromJson(Map<String, dynamic> json) {
    return SellerDishSubcategory(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String?,
      imageUrl: Optica2AssetUrl.resolve(json['image_url'] as String?),
    );
  }
}

/// Menu category from admin (e.g. Biryani, Rice, Curries).
class SellerDishCategory {
  const SellerDishCategory({
    required this.id,
    required this.name,
    this.slug,
    this.imageUrl,
    this.subcategories = const [],
  });

  final int id;
  final String name;
  final String? slug;
  final String? imageUrl;
  final List<SellerDishSubcategory> subcategories;

  factory SellerDishCategory.fromJson(Map<String, dynamic> json) {
    final rawSubs = json['subcategories'];
    final subs = rawSubs is List
        ? rawSubs
            .whereType<Map<String, dynamic>>()
            .map(SellerDishSubcategory.fromJson)
            .where((s) => s.id > 0)
            .toList()
        : const <SellerDishSubcategory>[];

    return SellerDishCategory(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String?,
      imageUrl: Optica2AssetUrl.resolve(json['image_url'] as String?),
      subcategories: subs,
    );
  }
}
