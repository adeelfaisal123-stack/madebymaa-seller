class SellerAccountProfile {
  const SellerAccountProfile({
    required this.id,
    required this.name,
    required this.phoneE164,
    required this.email,
    required this.address,
    required this.city,
    required this.state,
    required this.country,
    this.addressChangeStatus,
  });

  final int id;
  final String name;
  final String phoneE164;
  final String email;
  final String address;
  final String city;
  final String state;
  final String country;
  final String? addressChangeStatus;

  factory SellerAccountProfile.fromJson(Map<String, dynamic>? json) {
    if (json == null) return SellerAccountProfile.empty;

    int i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    String s(dynamic v) => v == null ? '' : '$v'.trim();

    return SellerAccountProfile(
      id: i(json['id']),
      name: s(json['name']),
      phoneE164: s(json['phone']),
      email: s(json['email']),
      address: s(json['address']),
      city: s(json['city']),
      state: s(json['state']),
      country: s(json['country']),
      addressChangeStatus: json['address_change_status'] as String?,
    );
  }

  static const empty = SellerAccountProfile(
    id: 0,
    name: '',
    phoneE164: '',
    email: '',
    address: '',
    city: '',
    state: '',
    country: '',
    addressChangeStatus: null,
  );

  SellerAccountProfile copyWith({
    int? id,
    String? name,
    String? phoneE164,
    String? email,
    String? address,
    String? city,
    String? state,
    String? country,
    String? addressChangeStatus,
  }) {
    return SellerAccountProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneE164: phoneE164 ?? this.phoneE164,
      email: email ?? this.email,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      addressChangeStatus: addressChangeStatus ?? this.addressChangeStatus,
    );
  }
}
