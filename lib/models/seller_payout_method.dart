enum SellerPayoutMethodType {
  bank,
  upi;

  static SellerPayoutMethodType fromApi(String? raw) {
    return raw == 'upi' ? upi : bank;
  }

  String get apiValue => this == upi ? 'upi' : 'bank';

  String get label => this == upi ? 'UPI' : 'Bank account';
}

class SellerPayoutMethod {
  const SellerPayoutMethod({
    required this.id,
    required this.type,
    required this.typeLabel,
    required this.label,
    required this.subtitle,
    this.bankName,
    this.bankAccountTitle,
    this.bankAccountNumber,
    this.bankIfsc,
    this.upiId,
  });

  final int id;
  final SellerPayoutMethodType type;
  final String typeLabel;
  final String label;
  final String subtitle;
  final String? bankName;
  final String? bankAccountTitle;
  final String? bankAccountNumber;
  final String? bankIfsc;
  final String? upiId;

  bool get isUpi => type == SellerPayoutMethodType.upi;

  factory SellerPayoutMethod.fromJson(Map<String, dynamic> json) {
    return SellerPayoutMethod(
      id: json['id'] as int,
      type: SellerPayoutMethodType.fromApi(json['type'] as String?),
      typeLabel: _s(json['type_label']),
      label: _s(json['label']),
      subtitle: _s(json['subtitle']),
      bankName: json['bank_name'] as String?,
      bankAccountTitle: json['bank_account_title'] as String?,
      bankAccountNumber: json['bank_account_number'] as String?,
      bankIfsc: json['bank_ifsc'] as String?,
      upiId: json['upi_id'] as String?,
    );
  }

  static String _s(Object? value) => value == null ? '' : '$value'.trim();
}
