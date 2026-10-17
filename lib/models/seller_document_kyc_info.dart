import '../config/optica2_asset_url.dart';
import '../services/optica2_api.dart';

/// Document KYC details from Optica2 `document_kyc` on kyc-status.
class SellerDocumentKycInfo {
  const SellerDocumentKycInfo({
    required this.status,
    required this.hasUploads,
    this.aadhaarNumber,
    this.fssaiNumber,
    this.aadhaarFrontUrl,
    this.aadhaarBackUrl,
    this.fssaiDocumentUrl,
    this.fssaiIsPdf = false,
    this.agreementSignedUrl,
    this.agreementPdfUrl,
    this.agreementDate,
    this.agreementPlace,
  });

  final SellerDocumentKycStatusKind status;
  final bool hasUploads;
  final String? aadhaarNumber;
  final String? fssaiNumber;
  final String? aadhaarFrontUrl;
  final String? aadhaarBackUrl;
  final String? fssaiDocumentUrl;
  final bool fssaiIsPdf;
  final String? agreementSignedUrl;
  final String? agreementPdfUrl;
  final String? agreementDate;
  final String? agreementPlace;

  bool get canViewDocuments => hasUploads;

  String get displayLabel => status.displayLabel;

  factory SellerDocumentKycInfo.fromJson(Map<String, dynamic> json) {
    return SellerDocumentKycInfo(
      status: SellerDocumentKycStatusKind.fromApi(json['status'] as String?),
      hasUploads: json['has_uploads'] == true,
      aadhaarNumber: json['aadhaar_number'] as String?,
      fssaiNumber: json['fssai_number'] as String?,
      aadhaarFrontUrl:
          Optica2AssetUrl.resolve(json['aadhaar_front_url'] as String?),
      aadhaarBackUrl:
          Optica2AssetUrl.resolve(json['aadhaar_back_url'] as String?),
      fssaiDocumentUrl:
          Optica2AssetUrl.resolve(json['fssai_document_url'] as String?),
      fssaiIsPdf: json['fssai_is_pdf'] == true,
      agreementSignedUrl:
          Optica2AssetUrl.resolve(json['agreement_signed_url'] as String?),
      agreementPdfUrl:
          Optica2AssetUrl.resolve(json['agreement_pdf_url'] as String?),
      agreementDate: json['agreement_date'] as String?,
      agreementPlace: json['agreement_place'] as String?,
    );
  }

}
