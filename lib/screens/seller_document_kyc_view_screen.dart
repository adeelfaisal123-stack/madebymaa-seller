import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/seller_document_kyc_info.dart';
import '../services/optica2_api.dart';
import '../theme/app_colors.dart';
import '../widgets/app_toast.dart';
import 'agreement_pdf_viewer_screen.dart';

/// Read-only view of submitted Aadhaar / FSSAI documents.
class SellerDocumentKycViewScreen extends StatelessWidget {
  const SellerDocumentKycViewScreen({
    super.key,
    required this.documentKyc,
  });

  final SellerDocumentKycInfo documentKyc;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.deepGreen),
        title: Text(
          'KYC documents',
          style: GoogleFonts.exo2(
            fontWeight: FontWeight.w800,
            color: AppColors.deepGreen,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          _StatusBanner(status: documentKyc.status),
          const SizedBox(height: 20),
          if (documentKyc.aadhaarNumber != null &&
              documentKyc.aadhaarNumber!.isNotEmpty) ...[
            Text(
              'Aadhaar number',
              style: GoogleFonts.exo2(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.deepGreen.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.brandPurple.withValues(alpha: 0.15),
                ),
              ),
              child: Text(
                documentKyc.aadhaarNumber!,
                style: GoogleFonts.exo2(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.08,
                  color: AppColors.deepGreen,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          if (documentKyc.fssaiNumber != null &&
              documentKyc.fssaiNumber!.isNotEmpty) ...[
            Text(
              'FSSAI license number',
              style: GoogleFonts.exo2(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.deepGreen.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.brandPurple.withValues(alpha: 0.15),
                ),
              ),
              child: Text(
                documentKyc.fssaiNumber!,
                style: GoogleFonts.exo2(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.04,
                  color: AppColors.deepGreen,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          Text(
            'Aadhaar card',
            style: GoogleFonts.exo2(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.deepGreen,
            ),
          ),
          const SizedBox(height: 10),
          _DocumentImageTile(
            label: 'Front',
            imageUrl: documentKyc.aadhaarFrontUrl,
          ),
          const SizedBox(height: 12),
          _DocumentImageTile(
            label: 'Back',
            imageUrl: documentKyc.aadhaarBackUrl,
          ),
          const SizedBox(height: 24),
          Text(
            'FSSAI certificate',
            style: GoogleFonts.exo2(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.deepGreen,
            ),
          ),
          const SizedBox(height: 10),
          if (documentKyc.fssaiIsPdf)
            _PdfDocumentTile(url: documentKyc.fssaiDocumentUrl, label: 'FSSAI PDF')
          else
            _DocumentImageTile(
              label: 'Document',
              imageUrl: documentKyc.fssaiDocumentUrl,
            ),
          if (documentKyc.agreementPdfUrl != null &&
              documentKyc.agreementPdfUrl!.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Signed agreement',
              style: GoogleFonts.exo2(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.deepGreen,
              ),
            ),
            const SizedBox(height: 10),
            _PdfDocumentTile(
              url: documentKyc.agreementPdfUrl,
              label: 'Signed agreement PDF',
            ),
          ],
          if (documentKyc.agreementSignedUrl != null &&
              documentKyc.agreementSignedUrl!.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Agreement signature',
              style: GoogleFonts.exo2(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.deepGreen,
              ),
            ),
            const SizedBox(height: 10),
            _DocumentImageTile(
              label: 'Signature',
              imageUrl: documentKyc.agreementSignedUrl,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});

  final SellerDocumentKycStatusKind status;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, IconData icon) = switch (status) {
      SellerDocumentKycStatusKind.approved => (
          AppColors.sage.withValues(alpha: 0.18),
          AppColors.sage,
          Icons.check_circle_outline_rounded,
        ),
      SellerDocumentKycStatusKind.pending => (
          AppColors.bootstrapWarningBg,
          AppColors.bootstrapWarningText,
          Icons.hourglass_top_rounded,
        ),
      SellerDocumentKycStatusKind.rejected => (
          AppColors.kitchenOff.withValues(alpha: 0.12),
          AppColors.kitchenOff,
          Icons.cancel_outlined,
        ),
      _ => (
          AppColors.brandPurple.withValues(alpha: 0.1),
          AppColors.brandPurple,
          Icons.info_outline_rounded,
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: status == SellerDocumentKycStatusKind.pending
              ? AppColors.bootstrapWarningBorder
              : fg.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 22),
          const SizedBox(width: 10),
          Text(
            'Status: ${status.displayLabel}',
            style: GoogleFonts.exo2(
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentImageTile extends StatelessWidget {
  const _DocumentImageTile({
    required this.label,
    required this.imageUrl,
  });

  final String label;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.exo2(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.deepGreen.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 160),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.brandPurple.withValues(alpha: 0.12),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: imageUrl != null && imageUrl!.isNotEmpty
              ? Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const SizedBox(
                      height: 180,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.brandPurple,
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, _, _) => _missing(label),
                )
              : _missing(label),
        ),
      ],
    );
  }

  Widget _missing(String label) {
    return SizedBox(
      height: 140,
      child: Center(
        child: Text(
          '$label not available',
          style: GoogleFonts.exo2(
            color: AppColors.deepGreen.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }
}

class _PdfDocumentTile extends StatelessWidget {
  const _PdfDocumentTile({required this.url, this.label = 'PDF document'});

  final String? url;
  final String label;

  Future<void> _open(BuildContext context) async {
    if (url == null || url!.isEmpty) {
      AppToast.warning(context, 'PDF not available.');
      return;
    }
    await openAgreementPdf(context, url!);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.brandPurple.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.terracotta.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: AppColors.terracotta,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.exo2(
                        fontWeight: FontWeight.w700,
                        color: AppColors.deepGreen,
                      ),
                    ),
                    Text(
                      'Tap to open in browser',
                      style: GoogleFonts.exo2(
                        fontSize: 12,
                        color: AppColors.deepGreen.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new_rounded, color: AppColors.brandPurple),
            ],
          ),
        ),
      ),
    );
  }
}
