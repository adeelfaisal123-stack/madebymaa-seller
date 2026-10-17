import '../config/optica2_asset_url.dart';
import '../data/seller_agreement_content.dart';
import '../services/seller_agreement_personalizer.dart';

/// Seller agreement template from admin panel (document KYC step).
class SellerKycAgreementTemplate {
  const SellerKycAgreementTemplate({
    required this.title,
    required this.hasTemplate,
    required this.content,
    required this.sellerName,
    required this.kitchenName,
    required this.place,
    required this.agreementDate,
    this.pdfUrl,
  });

  final String title;
  final bool hasTemplate;
  final String content;
  final String sellerName;
  final String kitchenName;
  final String place;
  final String agreementDate;
  final String? pdfUrl;

  SellerAgreementContext get context => SellerAgreementContext(
        sellerName: sellerName,
        kitchenName: kitchenName,
        place: place,
        agreementDate: agreementDate,
      );

  String get displayContent =>
      displaySegments.map((segment) => segment.text).join();

  List<AgreementTextSegment> get displaySegments {
    final raw = content.trim().isNotEmpty ? content : sellerAgreementDefaultContent;
    return buildAgreementSegments(raw, context);
  }

  factory SellerKycAgreementTemplate.fromJson(Map<String, dynamic> json) {
    final rawContent = (json['content'] as String?)?.trim() ?? '';
    final agreementDate = (json['agreement_date'] as String?)?.trim() ?? '';
    return SellerKycAgreementTemplate(
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? (json['title'] as String).trim()
          : 'Seller agreement',
      hasTemplate: json['has_template'] == true,
      content: rawContent.isNotEmpty ? rawContent : sellerAgreementDefaultContent,
      sellerName: (json['seller_name'] as String?)?.trim() ?? '',
      kitchenName: (json['kitchen_name'] as String?)?.trim() ?? '',
      place: (json['place'] as String?)?.trim() ?? '',
      agreementDate: agreementDate.isNotEmpty
          ? agreementDate
          : formatAgreementDate(DateTime.now()),
      pdfUrl: Optica2AssetUrl.resolve(json['pdf_url'] as String?),
    );
  }
}
