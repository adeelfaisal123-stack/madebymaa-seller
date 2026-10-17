class SellerAddressInfo {
  const SellerAddressInfo({
    required this.address,
    required this.city,
    required this.state,
    required this.country,
    required this.hasAddress,
    this.zoneId,
    this.zoneName,
    this.latitude,
    this.longitude,
    this.changeStatus,
    this.changeSubmittedAt,
    this.pending,
    required this.formatted,
  });

  final String address;
  final String city;
  final String state;
  final String country;
  final bool hasAddress;
  final int? zoneId;
  final String? zoneName;
  final double? latitude;
  final double? longitude;
  final String? changeStatus;
  final String? changeSubmittedAt;
  final SellerAddressSnapshot? pending;
  final String formatted;

  bool get isPending => changeStatus == 'pending';
  bool get isRejected => changeStatus == 'rejected';
  bool get canSubmitChange => !isPending;

  String get subtitle {
    if (isPending) return 'Awaiting admin approval';
    if (zoneName != null && zoneName!.trim().isNotEmpty) {
      return zoneName!.trim();
    }
    if (formatted.isNotEmpty) return formatted;
    return 'Add your address';
  }

  factory SellerAddressInfo.fromJson(Map<String, dynamic> json) {
    final pendingJson = json['pending'];
    return SellerAddressInfo(
      address: _s(json['address']),
      city: _s(json['city']),
      state: _s(json['state']),
      country: _s(json['country']),
      hasAddress: json['has_address'] == true,
      zoneId: _parseInt(json['zone_id']),
      zoneName: json['zone_name'] as String?,
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
      changeStatus: json['change_status'] as String?,
      changeSubmittedAt: json['change_submitted_at'] as String?,
      pending: pendingJson is Map<String, dynamic>
          ? SellerAddressSnapshot.fromJson(pendingJson)
          : null,
      formatted: _s(json['formatted']),
    );
  }

  static String _s(Object? value) => value == null ? '' : '$value'.trim();

  static int? _parseInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _parseDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

class SellerAddressSnapshot {
  const SellerAddressSnapshot({
    required this.address,
    required this.city,
    required this.state,
    required this.country,
    this.zoneId,
    this.zoneName,
    this.latitude,
    this.longitude,
    required this.formatted,
  });

  final String address;
  final String city;
  final String state;
  final String country;
  final int? zoneId;
  final String? zoneName;
  final double? latitude;
  final double? longitude;
  final String formatted;

  factory SellerAddressSnapshot.fromJson(Map<String, dynamic> json) {
    return SellerAddressSnapshot(
      address: SellerAddressInfo._s(json['address']),
      city: SellerAddressInfo._s(json['city']),
      state: SellerAddressInfo._s(json['state']),
      country: SellerAddressInfo._s(json['country']),
      zoneId: SellerAddressInfo._parseInt(json['zone_id']),
      zoneName: json['zone_name'] as String?,
      latitude: SellerAddressInfo._parseDouble(json['latitude']),
      longitude: SellerAddressInfo._parseDouble(json['longitude']),
      formatted: SellerAddressInfo._s(json['formatted']),
    );
  }
}
