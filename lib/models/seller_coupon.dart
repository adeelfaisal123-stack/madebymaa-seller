import 'seller_dish.dart';

/// Restaurant coupon (percent or flat discount).
class SellerCoupon {
  const SellerCoupon({
    required this.id,
    required this.code,
    required this.title,
    this.description,
    required this.discountType,
    required this.discountValue,
    required this.discountLabel,
    this.minPurchaseAmount,
    this.minPurchaseLabel,
    this.maxDiscountableAmount,
    this.maxDiscountableLabel,
    this.isActive = true,
  });

  final int id;
  final String code;
  final String title;
  final String? description;
  final DishDiscountType discountType;
  final double discountValue;
  final String discountLabel;
  final double? minPurchaseAmount;
  final String? minPurchaseLabel;
  final double? maxDiscountableAmount;
  final String? maxDiscountableLabel;
  final bool isActive;

  String get displayTitle => title.trim().isNotEmpty ? title.trim() : code;

  SellerCoupon copyWith({bool? isActive}) {
    return SellerCoupon(
      id: id,
      code: code,
      title: title,
      description: description,
      discountType: discountType,
      discountValue: discountValue,
      discountLabel: discountLabel,
      minPurchaseAmount: minPurchaseAmount,
      minPurchaseLabel: minPurchaseLabel,
      maxDiscountableAmount: maxDiscountableAmount,
      maxDiscountableLabel: maxDiscountableLabel,
      isActive: isActive ?? this.isActive,
    );
  }

  factory SellerCoupon.fromJson(Map<String, dynamic> json) {
    return SellerCoupon(
      id: json['id'] as int,
      code: json['code'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      discountType: DishDiscountType.fromApi(json['discount_type'] as String?),
      discountValue: _toDouble(json['discount_value']),
      discountLabel: json['discount_label'] as String? ?? '',
      minPurchaseAmount: _toNullableDouble(json['min_purchase_amount']),
      minPurchaseLabel: json['min_purchase_label'] as String?,
      maxDiscountableAmount: _toNullableDouble(json['max_discountable_amount']),
      maxDiscountableLabel: json['max_discountable_label'] as String?,
      isActive: json['is_active'] != false,
    );
  }

  static double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  static double? _toNullableDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }
}
