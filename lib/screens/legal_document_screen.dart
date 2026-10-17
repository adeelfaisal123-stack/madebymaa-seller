import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/seller_legal_document.dart';
import '../services/optica2_api.dart';
import '../theme/app_colors.dart';
import '../widgets/app_toast.dart';

/// Displays terms & conditions or privacy policy.
class LegalDocumentScreen extends StatefulWidget {
  const LegalDocumentScreen({
    super.key,
    required this.documentKey,
    this.initialDocument,
  });

  /// `terms` or `privacy`.
  final String documentKey;
  final SellerLegalDocument? initialDocument;

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  final _api = Optica2Api();
  bool _loading = true;
  SellerLegalDocument? _document;

  @override
  void initState() {
    super.initState();
    if (widget.initialDocument != null) {
      _document = widget.initialDocument;
      _loading = false;
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final document = await _api.fetchSellerLegalDocument(
        type: widget.documentKey,
      );
      if (!mounted) return;
      setState(() {
        _document = document;
        _loading = false;
      });
    } on Optica2ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppToast.danger(context, e.message);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = _document;
    final title = doc?.title ??
        (widget.documentKey == 'privacy'
            ? 'Privacy Policy'
            : 'Terms & Conditions');

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.deepGreen),
        title: Text(
          title,
          style: GoogleFonts.exo2(
            fontWeight: FontWeight.w800,
            color: AppColors.deepGreen,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.brandPurple),
            )
          : doc == null || doc.body.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Could not load this document.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.exo2(color: AppColors.deepGreen),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.brandPurple.withValues(alpha: 0.15),
                        ),
                      ),
                      child: SelectableText(
                        doc.body,
                        style: GoogleFonts.exo2(
                          fontSize: 14,
                          height: 1.55,
                          color: AppColors.deepGreen.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
