import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../data/seller_agreement_content.dart';
import '../models/kyc_upload_file.dart';
import '../models/seller_kyc_agreement_template.dart';
import '../seller_session_prefs.dart';
import '../services/document_kyc_draft_store.dart';
import '../services/optica2_api.dart';
import '../services/seller_agreement_personalizer.dart';
import '../services/seller_agreement_pdf_service.dart';
import '../theme/app_colors.dart';
import '../widgets/agreement_highlighted_text.dart';
import '../widgets/app_toast.dart';
import '../widgets/signature_dialog.dart';

/// Multi-step Aadhaar + FSSAI upload for document KYC.
class SellerDocumentKycScreen extends StatefulWidget {
  const SellerDocumentKycScreen({
    super.key,
    required this.phoneE164,
    this.initialStatus = SellerDocumentKycStatusKind.notSubmitted,
  });

  final String phoneE164;
  final SellerDocumentKycStatusKind initialStatus;

  @override
  State<SellerDocumentKycScreen> createState() => _SellerDocumentKycScreenState();
}

class _SellerDocumentKycScreenState extends State<SellerDocumentKycScreen> {
  final _aadhaarController = TextEditingController();
  final _fssaiController = TextEditingController();
  final _api = Optica2Api();
  final _picker = ImagePicker();

  int _step = 0;
  String? _aadhaarNumber;
  String? _fssaiNumber;
  XFile? _aadhaarFront;
  XFile? _aadhaarBack;
  XFile? _fssaiDoc;
  Uint8List? _aadhaarFrontBytes;
  Uint8List? _aadhaarBackBytes;
  Uint8List? _fssaiDocBytes;
  Uint8List? _signatureBytes;
  bool _agreementAccepted = false;
  bool _hasSignature = false;
  bool _submitting = false;
  bool _restoringDraft = false;
  Timer? _draftSaveTimer;
  SellerKycAgreementTemplate? _agreementTemplate;
  bool _loadingAgreement = true;

  static const _steps = ['Aadhaar card', 'FSSAI license', 'Agreement'];

  @override
  void initState() {
    super.initState();
    _aadhaarController.addListener(_scheduleDraftSave);
    _fssaiController.addListener(_scheduleDraftSave);
    unawaited(_restoreDraft());
    _loadAgreement();
  }

  Future<void> _restoreDraft() async {
    final draft = await DocumentKycDraftStore.load(widget.phoneE164);
    if (!mounted || draft == null) return;

    _restoringDraft = true;
    setState(() {
      _step = draft.step.clamp(0, 2);
      if (draft.aadhaarNumber != null && draft.aadhaarNumber!.isNotEmpty) {
        _aadhaarNumber = draft.aadhaarNumber;
        _aadhaarController.text = draft.aadhaarNumber!;
      }
      if (draft.fssaiNumber != null && draft.fssaiNumber!.isNotEmpty) {
        _fssaiNumber = draft.fssaiNumber;
        _fssaiController.text = draft.fssaiNumber!;
      }
      _agreementAccepted = draft.agreementAccepted;
      if (draft.aadhaarFrontBytes != null) {
        _aadhaarFrontBytes = draft.aadhaarFrontBytes;
        _aadhaarFront = XFile.fromData(
          draft.aadhaarFrontBytes!,
          name: 'aadhaar_front.jpg',
          mimeType: 'image/jpeg',
        );
      }
      if (draft.aadhaarBackBytes != null) {
        _aadhaarBackBytes = draft.aadhaarBackBytes;
        _aadhaarBack = XFile.fromData(
          draft.aadhaarBackBytes!,
          name: 'aadhaar_back.jpg',
          mimeType: 'image/jpeg',
        );
      }
      if (draft.fssaiDocBytes != null) {
        _fssaiDocBytes = draft.fssaiDocBytes;
        _fssaiDoc = XFile.fromData(
          draft.fssaiDocBytes!,
          name: 'fssai_document.jpg',
          mimeType: 'image/jpeg',
        );
      }
      if (draft.hasSignature) {
        _signatureBytes = draft.signatureBytes;
        _hasSignature = true;
      }
    });
    _restoringDraft = false;
  }

  void _scheduleDraftSave() {
    if (_restoringDraft) return;
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(const Duration(milliseconds: 350), () {
      unawaited(_saveDraft());
    });
  }

  Future<void> _saveDraft() async {
    final aadhaar = _readAadhaarNumber();
    final fssai = _readFssaiNumber();

    await DocumentKycDraftStore.save(
      phoneE164: widget.phoneE164,
      step: _step,
      aadhaarNumber: aadhaar,
      fssaiNumber: fssai,
      agreementAccepted: _agreementAccepted,
      aadhaarFrontBytes: _aadhaarFrontBytes,
      aadhaarBackBytes: _aadhaarBackBytes,
      fssaiDocBytes: _fssaiDocBytes,
      signatureBytes: _signatureBytes,
    );
  }

  Future<void> _updateDraft(VoidCallback update) async {
    setState(update);
    await _saveDraft();
  }

  Future<void> _loadAgreement() async {
    try {
      final sellerId = await SellerSessionPrefs.sellerId();
      final template = await _api.fetchSellerKycAgreement(
        phoneE164: widget.phoneE164,
        sellerId: sellerId,
      );
      if (!mounted) return;
      setState(() {
        _agreementTemplate = template;
        _loadingAgreement = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingAgreement = false);
    }
  }

  @override
  void dispose() {
    _draftSaveTimer?.cancel();
    unawaited(_saveDraft());
    _aadhaarController.removeListener(_scheduleDraftSave);
    _fssaiController.removeListener(_scheduleDraftSave);
    _api.close();
    _aadhaarController.dispose();
    _fssaiController.dispose();
    super.dispose();
  }

  String _digitsOnly(String value) => value.replaceAll(RegExp(r'\D'), '');

  bool _isValidAadhaar(String aadhaar) =>
      aadhaar.length == 12 && !RegExp(r'^[01]').hasMatch(aadhaar);

  String? _readAadhaarNumber() {
    final cached = _aadhaarNumber;
    if (cached != null && _isValidAadhaar(cached)) return cached;
    final entered = _digitsOnly(_aadhaarController.text);
    return _isValidAadhaar(entered) ? entered : null;
  }

  String? _readFssaiNumber() {
    final cached = _fssaiNumber;
    if (cached != null && cached.length == 14) return cached;
    final entered = _digitsOnly(_fssaiController.text);
    return entered.length == 14 ? entered : null;
  }

  Future<void> _pickImage(void Function(XFile file, Uint8List bytes) onPicked) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final file = await _picker.pickImage(
      source: source,
      maxWidth: 2000,
      imageQuality: 88,
    );
    if (file != null) {
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      onPicked(file, bytes);
      await _saveDraft();
    }
  }

  Future<Uint8List> _uploadBytes(XFile file, Uint8List? cached) async {
    if (cached != null && cached.isNotEmpty) return cached;
    return file.readAsBytes();
  }

  Future<void> _openSignatureDialog() async {
    final bytes = await showSignatureDialog(
      context,
      initialBytes: _signatureBytes,
    );
    if (bytes == null || !mounted) return;
    await _updateDraft(() {
      _signatureBytes = bytes;
      _hasSignature = true;
    });
  }

  Future<void> _clearSignature() async {
    await _updateDraft(() {
      _hasSignature = false;
      _signatureBytes = null;
    });
  }

  Future<Uint8List> _buildSignedAgreementPdfBytes() async {
    final signatureBytes = _signatureBytes;
    if (signatureBytes == null || signatureBytes.isEmpty) {
      throw StateError('Missing signature');
    }

    final segments = _agreementTemplate?.displaySegments ??
        buildAgreementSegments(
          sellerAgreementDefaultContent,
          SellerAgreementContext(
            sellerName: _agreementTemplate?.sellerName ?? '',
            kitchenName: _agreementTemplate?.kitchenName ?? '',
            place: _agreementTemplate?.place ?? '',
            agreementDate: _agreementTemplate?.agreementDate ??
                formatAgreementDate(DateTime.now()),
          ),
        );

    return buildSellerAgreementPdf(
      segments: segments,
      signaturePng: signatureBytes,
    );
  }

  Future<void> _downloadAgreement() async {
    if (!_hasSignature) {
      AppToast.warning(
        context,
        'Add your signature before downloading the agreement PDF.',
      );
      return;
    }

    final signatureBytes = _signatureBytes;
    if (signatureBytes == null || signatureBytes.isEmpty) {
      if (mounted) {
        AppToast.warning(context, 'Add your signature before downloading.');
      }
      return;
    }

    try {
      final pdfBytes = await _buildSignedAgreementPdfBytes();
      if (!mounted) return;
      final result = await downloadSellerAgreementPdf(pdfBytes);
      if (!mounted) return;
      if (result.success) {
        AppToast.success(
          context,
          result.message ?? 'Agreement downloaded to Downloads.',
        );
      } else {
        AppToast.danger(
          context,
          result.error ?? 'Could not save agreement PDF.',
        );
      }
    } catch (_) {
      if (mounted) {
        AppToast.danger(context, 'Could not generate agreement PDF.');
      }
    }
  }

  void _next() {
    if (_step == 0) {
      final aadhaar = _readAadhaarNumber();
      if (aadhaar == null) {
        AppToast.warning(context, 'Enter a valid 12-digit Aadhaar number.');
        return;
      }
      _aadhaarNumber = aadhaar;
      if (_aadhaarFront == null) {
        AppToast.warning(context, 'Upload the front of your Aadhaar card.');
        return;
      }
      if (_aadhaarBack == null) {
        AppToast.warning(context, 'Upload the back of your Aadhaar card.');
        return;
      }
    }
    if (_step == 1) {
      final fssai = _readFssaiNumber();
      if (fssai == null) {
        AppToast.warning(context, 'Enter a valid 14-digit FSSAI license number.');
        return;
      }
      _fssaiNumber = fssai;
      if (_fssaiDoc == null) {
        AppToast.warning(context, 'Upload your FSSAI certificate or license.');
        return;
      }
    }
    if (_step == 2) {
      if (!_agreementAccepted) {
        AppToast.warning(
          context,
          'Accept the terms and conditions to continue.',
        );
        return;
      }
      if (!_hasSignature) {
        AppToast.warning(context, 'Add your digital signature to continue.');
        return;
      }
      _submit();
      return;
    }
    if (_step < 2) {
      setState(() => _step++);
      unawaited(_saveDraft());
    }
  }

  void _back() {
    if (_step == 0) {
      unawaited(_saveDraft());
      Navigator.of(context).pop(false);
      return;
    }
    setState(() => _step--);
    unawaited(_saveDraft());
  }

  Future<void> _submit() async {
    final aadhaar = _readAadhaarNumber();
    if (aadhaar == null) {
      AppToast.warning(context, 'Enter a valid 12-digit Aadhaar number.');
      setState(() => _step = 0);
      return;
    }
    _aadhaarNumber = aadhaar;

    final fssai = _readFssaiNumber();
    if (fssai == null) {
      AppToast.warning(context, 'Enter a valid 14-digit FSSAI license number.');
      setState(() => _step = 1);
      return;
    }
    _fssaiNumber = fssai;
    if (_fssaiDoc == null) {
      AppToast.warning(context, 'Upload your FSSAI certificate or license.');
      return;
    }
    if (_aadhaarFront == null || _aadhaarBack == null) {
      AppToast.warning(context, 'Complete Aadhaar uploads first.');
      return;
    }
    if (!_agreementAccepted) {
      AppToast.warning(context, 'Accept the terms and conditions to continue.');
      setState(() => _step = 2);
      return;
    }
    if (!_hasSignature) {
      AppToast.warning(context, 'Add your digital signature to continue.');
      setState(() => _step = 2);
      return;
    }

    final signatureBytes = _signatureBytes;
    if (signatureBytes == null || signatureBytes.isEmpty) {
      if (mounted) {
        AppToast.warning(context, 'Add your digital signature to continue.');
        setState(() => _step = 2);
      }
      return;
    }

    setState(() => _submitting = true);

    try {
      final sellerId = await SellerSessionPrefs.sellerId();
      final frontBytes = await _uploadBytes(_aadhaarFront!, _aadhaarFrontBytes);
      final backBytes = await _uploadBytes(_aadhaarBack!, _aadhaarBackBytes);
      final fssaiBytes = await _uploadBytes(_fssaiDoc!, _fssaiDocBytes);
      final agreementPdfBytes = await _buildSignedAgreementPdfBytes();
      final message = await _api.submitDocumentKyc(
        phoneE164: widget.phoneE164,
        aadhaarNumber: aadhaar,
        fssaiNumber: fssai,
        aadhaarFront: _aadhaarFront!,
        aadhaarBack: _aadhaarBack!,
        fssaiDocument: _fssaiDoc!,
        aadhaarFrontBytes: frontBytes,
        aadhaarBackBytes: backBytes,
        fssaiDocumentBytes: fssaiBytes,
        agreementSignature: KycUploadFile(
          name: 'agreement_signature.png',
          bytes: signatureBytes,
        ),
        agreementPdf: KycUploadFile(
          name: 'seller-agreement.pdf',
          bytes: agreementPdfBytes,
        ),
        sellerId: sellerId,
      );
      if (!mounted) return;
      await DocumentKycDraftStore.clear(widget.phoneE164);
      if (!mounted) return;
      AppToast.success(context, message);
      Navigator.of(context).pop(true);
    } on Optica2ApiException catch (e) {
      if (!mounted) return;
      AppToast.danger(context, e.message);
    } catch (_) {
      if (!mounted) return;
      AppToast.danger(context, 'Upload failed. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingReview =
        widget.initialStatus == SellerDocumentKycStatusKind.pending;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.deepGreen),
          onPressed: _submitting ? null : _back,
        ),
        title: Text(
          'Document KYC',
          style: GoogleFonts.exo2(
            fontWeight: FontWeight.w800,
            color: AppColors.deepGreen,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StepIndicator(current: _step, labels: _steps),
                if (pendingReview) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bootstrapWarningBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.bootstrapWarningBorder,
                      ),
                    ),
                    child: Text(
                      'Your documents are under review. You can upload again if admin requested changes.',
                      style: GoogleFonts.exo2(
                        fontSize: 13,
                        height: 1.35,
                        color: AppColors.bootstrapWarningText,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _step,
              children: [
                _AadhaarStep(
                  numberController: _aadhaarController,
                  frontFile: _aadhaarFront,
                  backFile: _aadhaarBack,
                  frontPreviewBytes: _aadhaarFrontBytes,
                  backPreviewBytes: _aadhaarBackBytes,
                  onPickFront: () => _pickImage((file, bytes) {
                    setState(() {
                      _aadhaarFront = file;
                      _aadhaarFrontBytes = bytes;
                    });
                  }),
                  onPickBack: () => _pickImage((file, bytes) {
                    setState(() {
                      _aadhaarBack = file;
                      _aadhaarBackBytes = bytes;
                    });
                  }),
                  onClearFront: () => _updateDraft(() {
                    _aadhaarFront = null;
                    _aadhaarFrontBytes = null;
                  }),
                  onClearBack: () => _updateDraft(() {
                    _aadhaarBack = null;
                    _aadhaarBackBytes = null;
                  }),
                ),
                _FssaiStep(
                  numberController: _fssaiController,
                  file: _fssaiDoc,
                  previewBytes: _fssaiDocBytes,
                  onPick: () => _pickImage((file, bytes) {
                    setState(() {
                      _fssaiDoc = file;
                      _fssaiDocBytes = bytes;
                    });
                  }),
                  onClear: () => _updateDraft(() {
                    _fssaiDoc = null;
                    _fssaiDocBytes = null;
                  }),
                ),
                _AgreementStep(
                  loading: _loadingAgreement,
                  template: _agreementTemplate,
                  displaySegments: _agreementTemplate?.displaySegments ?? const [],
                  signaturePreviewBytes: _hasSignature ? _signatureBytes : null,
                  accepted: _agreementAccepted,
                  onAcceptedChanged: (value) => _updateDraft(() {
                    _agreementAccepted = value;
                  }),
                  hasSignature: _hasSignature,
                  onSign: _openSignatureDialog,
                  onClearSignature: _clearSignature,
                  onDownload: _downloadAgreement,
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _submitting ? null : _next,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandPurple,
                    disabledBackgroundColor:
                        AppColors.brandPurple.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _step < 2 ? 'Continue' : 'Submit for review',
                          style: GoogleFonts.exo2(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current, required this.labels});

  final int current;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(labels.length, (i) {
        final active = i <= current;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.brandPurple
                            : AppColors.brandPurple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      labels[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.exo2(
                        fontSize: 11,
                        fontWeight: i == current ? FontWeight.w700 : FontWeight.w500,
                        color: active
                            ? AppColors.deepGreen
                            : AppColors.deepGreen.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),
              if (i < labels.length - 1) const SizedBox(width: 8),
            ],
          ),
        );
      }),
    );
  }
}

class _AadhaarStep extends StatelessWidget {
  const _AadhaarStep({
    required this.numberController,
    required this.frontFile,
    required this.backFile,
    required this.frontPreviewBytes,
    required this.backPreviewBytes,
    required this.onPickFront,
    required this.onPickBack,
    required this.onClearFront,
    required this.onClearBack,
  });

  final TextEditingController numberController;
  final XFile? frontFile;
  final XFile? backFile;
  final Uint8List? frontPreviewBytes;
  final Uint8List? backPreviewBytes;
  final VoidCallback onPickFront;
  final VoidCallback onPickBack;
  final VoidCallback onClearFront;
  final VoidCallback onClearBack;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Aadhaar card',
            style: GoogleFonts.exo2(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.deepGreen,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your Aadhaar number and upload clear photos of the front and back.',
            style: GoogleFonts.exo2(
              fontSize: 14,
              height: 1.4,
              color: AppColors.deepGreen.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: numberController,
            keyboardType: TextInputType.number,
            maxLength: 12,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Aadhaar number',
              counterText: '',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: AppColors.brandPurple.withValues(alpha: 0.2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _DocSectionHeader(
            label: 'Front side',
            showClear: frontFile != null,
            onClear: onClearFront,
          ),
          const SizedBox(height: 8),
          _DocPickerCard(
            file: frontFile,
            previewBytes: frontPreviewBytes,
            onPick: onPickFront,
            label: 'Tap to upload front',
            previewHeight: 160,
          ),
          const SizedBox(height: 20),
          _DocSectionHeader(
            label: 'Back side',
            showClear: backFile != null,
            onClear: onClearBack,
          ),
          const SizedBox(height: 8),
          _DocPickerCard(
            file: backFile,
            previewBytes: backPreviewBytes,
            onPick: onPickBack,
            label: 'Tap to upload back',
            previewHeight: 160,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _FssaiStep extends StatelessWidget {
  const _FssaiStep({
    required this.numberController,
    required this.file,
    required this.previewBytes,
    required this.onPick,
    required this.onClear,
  });

  final TextEditingController numberController;
  final XFile? file;
  final Uint8List? previewBytes;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FSSAI license',
            style: GoogleFonts.exo2(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.deepGreen,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your 14-digit FSSAI number and upload the certificate.',
            style: GoogleFonts.exo2(
              fontSize: 14,
              height: 1.4,
              color: AppColors.deepGreen.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: numberController,
            keyboardType: TextInputType.number,
            maxLength: 14,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'FSSAI number',
              counterText: '',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.brandPurple.withValues(alpha: 0.2)),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _DocSectionHeader(
            label: 'FSSAI document',
            showClear: file != null,
            onClear: onClear,
          ),
          const SizedBox(height: 8),
          _DocPickerCard(
            file: file,
            previewBytes: previewBytes,
            onPick: onPick,
            label: 'Tap to upload FSSAI document',
          ),
        ],
      ),
    );
  }
}

class _DocSectionHeader extends StatelessWidget {
  const _DocSectionHeader({
    required this.label,
    required this.showClear,
    required this.onClear,
  });

  final String label;
  final bool showClear;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.exo2(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.deepGreen.withValues(alpha: 0.7),
            ),
          ),
        ),
        if (showClear)
          TextButton(
            onPressed: onClear,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.terracotta,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Clear',
              style: GoogleFonts.exo2(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class _AgreementStep extends StatelessWidget {
  const _AgreementStep({
    required this.loading,
    required this.template,
    required this.displaySegments,
    required this.signaturePreviewBytes,
    required this.accepted,
    required this.onAcceptedChanged,
    required this.hasSignature,
    required this.onSign,
    required this.onClearSignature,
    required this.onDownload,
  });

  final bool loading;
  final SellerKycAgreementTemplate? template;
  final List<AgreementTextSegment> displaySegments;
  final Uint8List? signaturePreviewBytes;
  final bool accepted;
  final ValueChanged<bool> onAcceptedChanged;
  final bool hasSignature;
  final VoidCallback onSign;
  final VoidCallback onClearSignature;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final title = template?.title.isNotEmpty == true
        ? template!.title
        : 'Seller agreement';
    final showSignaturePreview =
        signaturePreviewBytes != null && signaturePreviewBytes!.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.exo2(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.deepGreen,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Read the agreement below, accept the terms, and sign.',
            style: GoogleFonts.exo2(
              fontSize: 14,
              height: 1.4,
              color: AppColors.deepGreen.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 20),
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(color: AppColors.brandPurple),
              ),
            )
          else ...[
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 320),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.deepGreen.withValues(alpha: 0.12),
                ),
              ),
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(right: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AgreementHighlightedText(segments: displaySegments),
                      if (showSignaturePreview) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Seller signature',
                          style: GoogleFonts.exo2(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.deepGreen.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Image.memory(
                          signaturePreviewBytes!,
                          height: 72,
                          fit: BoxFit.contain,
                          alignment: Alignment.centerLeft,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: onDownload,
                icon: const Icon(Icons.download_rounded),
                label: Text(
                  'Download signed agreement PDF',
                  style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brandPurple,
                  side: BorderSide(
                    color: AppColors.brandPurple.withValues(alpha: 0.45),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () => onAcceptedChanged(!accepted),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: accepted
                        ? AppColors.brandPurple.withValues(alpha: 0.45)
                        : AppColors.deepGreen.withValues(alpha: 0.12),
                  ),
                ),
                child: CheckboxListTile(
                  value: accepted,
                  onChanged: (value) => onAcceptedChanged(value ?? false),
                  activeColor: AppColors.brandPurple,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    'I agree to the terms and conditions',
                    style: GoogleFonts.exo2(
                      fontWeight: FontWeight.w700,
                      color: AppColors.deepGreen,
                    ),
                  ),
                  subtitle: Text(
                    'Required to submit KYC documents',
                    style: GoogleFonts.exo2(
                      fontSize: 12,
                      color: AppColors.deepGreen.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _DocSectionHeader(
            label: 'Digital signature',
            showClear: hasSignature,
            onClear: onClearSignature,
          ),
          const SizedBox(height: 8),
          if (hasSignature && signaturePreviewBytes != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.brandPurple.withValues(alpha: 0.25),
                ),
              ),
              child: Image.memory(
                signaturePreviewBytes!,
                height: 96,
                width: double.infinity,
                fit: BoxFit.contain,
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: onSign,
              icon: Icon(hasSignature ? Icons.edit_rounded : Icons.draw_rounded),
              label: Text(
                hasSignature ? 'Edit signature' : 'Add digital signature',
                style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _DocPickerCard extends StatelessWidget {
  const _DocPickerCard({
    required this.file,
    required this.previewBytes,
    required this.onPick,
    required this.label,
    this.previewHeight = 220,
  });

  final XFile? file;
  final Uint8List? previewBytes;
  final VoidCallback onPick;
  final String label;
  final double previewHeight;

  bool get _hasPreview =>
      previewBytes != null && previewBytes!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (_hasPreview) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.brandPurple.withValues(alpha: 0.25),
            width: 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            previewBytes!,
            height: previewHeight,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.brandPurple.withValues(alpha: 0.25),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.upload_file_rounded,
                size: 48,
                color: AppColors.brandPurple.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: GoogleFonts.exo2(
                  fontWeight: FontWeight.w600,
                  color: AppColors.deepGreen,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
