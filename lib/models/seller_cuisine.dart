import '../config/optica2_asset_url.dart';

class SellerCuisine {
  const SellerCuisine({
    required this.id,
    required this.name,
    this.imageUrl,
  });

  final int id;
  final String name;
  final String? imageUrl;

  factory SellerCuisine.fromJson(Map<String, dynamic> json) {
    return SellerCuisine(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? 'Cuisine',
      imageUrl: Optica2AssetUrl.resolve(json['image_url'] as String?),
    );
  }
}
