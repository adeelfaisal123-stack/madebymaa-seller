/// Vendor payout bank details from Optica2.
class SellerBankDetails {
  const SellerBankDetails({
    this.bankName,
    this.bankIban,
    this.bankAccountNumber,
    this.bankAccountTitle,
    this.isComplete = false,
  });

  final String? bankName;
  final String? bankIban;
  final String? bankAccountNumber;
  final String? bankAccountTitle;
  final bool isComplete;

  factory SellerBankDetails.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const SellerBankDetails();
    }
    return SellerBankDetails(
      bankName: json['bank_name'] as String?,
      bankIban: json['bank_iban'] as String?,
      bankAccountNumber: json['bank_account_number'] as String?,
      bankAccountTitle: json['bank_account_title'] as String?,
      isComplete: json['is_complete'] == true,
    );
  }

  String get profileSubtitle {
    if (!isComplete) return 'Add bank name, IBAN & account';
    return bankName ?? 'Saved';
  }
}
