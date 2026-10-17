import '../config/optica2_asset_url.dart';
import 'seller_cuisine.dart';

class SellerKitchenCuisines {
  const SellerKitchenCuisines({
    required this.selectedIds,
    required this.cuisines,
  });

  final List<int> selectedIds;
  final List<SellerCuisineOption> cuisines;

  factory SellerKitchenCuisines.fromJson(Map<String, dynamic> json) {
    final selected = json['selected_ids'];
    final cuisines = json['cuisines'];

    return SellerKitchenCuisines(
      selectedIds: selected is List
          ? selected.map((e) => (e as num).toInt()).toList()
          : const [],
      cuisines: cuisines is List
          ? cuisines
              .whereType<Map<String, dynamic>>()
              .map(SellerCuisineOption.fromJson)
              .toList()
          : const [],
    );
  }

  String get selectedLabel {
    final names = cuisines.where((c) => c.selected).map((c) => c.name).toList();
    if (names.isEmpty) return 'None selected';
    if (names.length <= 2) return names.join(', ');
    return '${names.take(2).join(', ')} +${names.length - 2}';
  }
}

class SellerCuisineOption extends SellerCuisine {
  const SellerCuisineOption({
    required super.id,
    required super.name,
    super.imageUrl,
    required this.selected,
  });

  final bool selected;

  factory SellerCuisineOption.fromJson(Map<String, dynamic> json) {
    return SellerCuisineOption(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? 'Cuisine',
      imageUrl: Optica2AssetUrl.resolve(json['image_url'] as String?),
      selected: json['selected'] == true,
    );
  }
}
