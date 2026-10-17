import '../config/optica2_asset_url.dart';
import 'seller_addon.dart';
import 'seller_super_category.dart';

/// Menu dish from Optica2 seller dishes API.
class SellerDish {
  const SellerDish({
    required this.id,
    this.superCategoryIds = const [],
    this.superCategories = const [],
    this.superCategoryId,
    this.superCategoryName,
    this.superCategoryTimeRange,
    this.dishCategoryId,
    this.dishSubcategoryId,
    this.dishCategoryName,
    this.dishSubcategoryName,
    required this.name,
    this.description,
    this.ingredients,
    this.tags = const [],
    required this.price,
    required this.discountType,
    this.discountValue,
    required this.effectivePrice,
    required this.isVeg,
    required this.imageUrls,
    this.isAvailable = true,
    this.availability,
    this.addonIds = const [],
    this.addons = const [],
  });

  final int id;
  final List<int> superCategoryIds;
  final List<SellerSuperCategory> superCategories;
  final int? superCategoryId;
  final String? superCategoryName;
  final String? superCategoryTimeRange;
  final int? dishCategoryId;
  final int? dishSubcategoryId;
  final String? dishCategoryName;
  final String? dishSubcategoryName;
  final String name;
  final String? description;
  final String? ingredients;
  final List<String> tags;
  final double price;
  final DishDiscountType discountType;
  final double? discountValue;
  final double effectivePrice;
  final bool isVeg;
  final List<String> imageUrls;
  final bool isAvailable;
  final Map<String, Map<String, bool>>? availability;
  final List<int> addonIds;
  final List<SellerAddon> addons;

  String get dietLabel => isVeg ? 'Veg' : 'Non-veg';

  String get tagsLabel => tags.join(', ');

  String get superCategoriesLabel => superCategories.isNotEmpty
      ? superCategories.map((c) => c.name).join(', ')
      : (superCategoryName ?? '');

  String get dishCategoryLabel {
    final category = dishCategoryName ?? '';
    final sub = dishSubcategoryName ?? '';
    if (category.isEmpty && sub.isEmpty) return '';
    if (sub.isEmpty) return category;
    if (category.isEmpty) return sub;
    return '$category · $sub';
  }

  SellerDish copyWith({bool? isAvailable}) {
    return SellerDish(
      id: id,
      superCategoryIds: superCategoryIds,
      superCategories: superCategories,
      superCategoryId: superCategoryId,
      superCategoryName: superCategoryName,
      superCategoryTimeRange: superCategoryTimeRange,
      dishCategoryId: dishCategoryId,
      dishSubcategoryId: dishSubcategoryId,
      dishCategoryName: dishCategoryName,
      dishSubcategoryName: dishSubcategoryName,
      name: name,
      description: description,
      ingredients: ingredients,
      tags: tags,
      price: price,
      discountType: discountType,
      discountValue: discountValue,
      effectivePrice: effectivePrice,
      isVeg: isVeg,
      imageUrls: imageUrls,
      isAvailable: isAvailable ?? this.isAvailable,
      availability: availability,
      addonIds: addonIds,
      addons: addons,
    );
  }

  String get priceLabel {
    if (discountType == DishDiscountType.none) {
      return '₹${effectivePrice.toStringAsFixed(0)}';
    }
    return '₹${effectivePrice.toStringAsFixed(0)}  '
        '(was ₹${price.toStringAsFixed(0)})';
  }

  factory SellerDish.fromJson(Map<String, dynamic> json) {
    final superCategories = _parseSuperCategories(json['super_categories']);
    final superCategoryIds = _parseSuperCategoryIds(json['super_category_ids']);
    final ids = superCategoryIds.isNotEmpty
        ? superCategoryIds
        : (superCategories.map((c) => c.id).where((id) => id > 0).toList());

    final superCat = json['super_category'];
    String? catName;
    String? catRange;
    if (superCat is Map<String, dynamic>) {
      catName = superCat['name'] as String?;
      catRange = superCat['time_range'] as String?;
    } else if (superCategories.isNotEmpty) {
      catName = superCategories.first.name;
      catRange = superCategories.first.timeRange;
    }

    final dishCat = json['dish_category'];
    final dishSub = json['dish_subcategory'];
    String? dishCategoryName;
    String? dishSubcategoryName;
    int? dishCategoryId = json['dish_category_id'] as int?;
    int? dishSubcategoryId = json['dish_subcategory_id'] as int?;
    if (dishCat is Map<String, dynamic>) {
      dishCategoryName = dishCat['name'] as String?;
      dishCategoryId ??= dishCat['id'] as int?;
    }
    if (dishSub is Map<String, dynamic>) {
      dishSubcategoryName = dishSub['name'] as String?;
      dishSubcategoryId ??= dishSub['id'] as int?;
    }

    return SellerDish(
      id: json['id'] as int,
      superCategoryIds: ids,
      superCategories: superCategories,
      superCategoryId: json['super_category_id'] as int? ??
          (superCat is Map ? superCat['id'] as int? : null) ??
          (ids.isNotEmpty ? ids.first : null),
      superCategoryName: catName,
      superCategoryTimeRange: catRange,
      dishCategoryId: dishCategoryId,
      dishSubcategoryId: dishSubcategoryId,
      dishCategoryName: dishCategoryName,
      dishSubcategoryName: dishSubcategoryName,
      name: json['name'] as String,
      description: json['description'] as String?,
      ingredients: json['ingredients'] as String?,
      tags: _parseTags(json['tags']),
      price: _toDouble(json['price']),
      discountType: DishDiscountType.fromApi(json['discount_type'] as String?),
      discountValue: json['discount_value'] != null
          ? _toDouble(json['discount_value'])
          : null,
      effectivePrice: _toDouble(json['effective_price']),
      isVeg: json['is_veg'] == true,
      imageUrls: _parseImageUrls(json),
      isAvailable: json['is_available'] != false,
      availability: _parseAvailability(json['availability']),
      addonIds: _parseAddonIds(json['addon_ids']),
      addons: _parseAddons(json['addons']),
    );
  }

  static List<String> _parseImageUrls(Map<String, dynamic> json) {
    final urls = <String>[];

    void add(Object? value) {
      final resolved = Optica2AssetUrl.resolve(value?.toString());
      if (resolved != null && resolved.isNotEmpty && !urls.contains(resolved)) {
        urls.add(resolved);
      }
    }

    final imageUrls = json['image_urls'];
    if (imageUrls is List) {
      for (final url in imageUrls) {
        add(url);
      }
    } else if (imageUrls is String) {
      add(imageUrls);
    }

    add(json['image_url']);

    final images = json['images'];
    if (images is List) {
      for (final image in images) {
        add(image);
      }
    } else if (images is String) {
      add(images);
    }

    return urls;
  }

  static List<int> _parseSuperCategoryIds(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => e is int ? e : int.tryParse('$e'))
        .whereType<int>()
        .where((id) => id > 0)
        .toList();
  }

  static List<SellerSuperCategory> _parseSuperCategories(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(SellerSuperCategory.fromJson)
        .where((c) => c.id > 0)
        .toList();
  }

  static List<int> _parseAddonIds(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => e is int ? e : int.tryParse('$e'))
        .whereType<int>()
        .where((id) => id > 0)
        .toList();
  }

  static List<SellerAddon> _parseAddons(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(SellerAddon.fromJson)
        .toList();
  }

  static Map<String, Map<String, bool>>? _parseAvailability(Object? raw) {
    if (raw is! Map) return null;
    final out = <String, Map<String, bool>>{};
    for (final entry in raw.entries) {
      if (entry.value is! Map) continue;
      out[entry.key.toString()] = Map<String, bool>.from(
        (entry.value as Map).map(
          (k, v) => MapEntry(k.toString(), v == true),
        ),
      );
    }
    return out.isEmpty ? null : out;
  }

  static double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  static List<String> _parseTags(Object? raw) {
    if (raw is List) {
      return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return raw
          .split(RegExp(r'[,#]+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }
}

enum DishDiscountType {
  none,
  percent,
  amount;

  static DishDiscountType fromApi(String? raw) {
    switch (raw) {
      case 'percent':
        return DishDiscountType.percent;
      case 'amount':
        return DishDiscountType.amount;
      default:
        return DishDiscountType.none;
    }
  }

  String get apiValue => name;

  String get label => switch (this) {
        DishDiscountType.none => 'No discount',
        DishDiscountType.percent => 'Percent off',
        DishDiscountType.amount => 'Flat off',
      };
}
