/// Optional extra sold with dishes (e.g. Cookie ₹50).
class SellerAddon {
  const SellerAddon({
    required this.id,
    required this.name,
    required this.price,
    this.isAvailable = true,
  });

  final int id;
  final String name;
  final double price;
  final bool isAvailable;

  String get priceLabel => '₹${price.toStringAsFixed(0)}';

  factory SellerAddon.fromJson(Map<String, dynamic> json) {
    return SellerAddon(
      id: json['id'] as int,
      name: json['name'] as String,
      price: _toDouble(json['price']),
      isAvailable: json['is_available'] != false,
    );
  }

  static double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }
}
