/// Terms or privacy policy text from the backend.
class SellerLegalDocument {
  const SellerLegalDocument({
    required this.key,
    required this.title,
    required this.body,
    this.updatedAt,
  });

  final String key;
  final String title;
  final String body;
  final String? updatedAt;

  factory SellerLegalDocument.fromJson(Map<String, dynamic> json) {
    return SellerLegalDocument(
      key: json['key'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      updatedAt: json['updated_at'] as String?,
    );
  }
}

class SellerLegalDocuments {
  const SellerLegalDocuments({
    required this.terms,
    required this.privacy,
  });

  final SellerLegalDocument terms;
  final SellerLegalDocument privacy;

  factory SellerLegalDocuments.fromJson(Map<String, dynamic> json) {
    final termsJson = json['terms'];
    final privacyJson = json['privacy'];

    return SellerLegalDocuments(
      terms: termsJson is Map<String, dynamic>
          ? SellerLegalDocument.fromJson(termsJson)
          : const SellerLegalDocument(key: 'terms', title: 'Terms & Conditions', body: ''),
      privacy: privacyJson is Map<String, dynamic>
          ? SellerLegalDocument.fromJson(privacyJson)
          : const SellerLegalDocument(key: 'privacy', title: 'Privacy Policy', body: ''),
    );
  }
}
