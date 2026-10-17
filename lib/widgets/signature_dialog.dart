import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import 'signature_pad.dart';

/// Full-screen-style dialog for capturing a digital signature.
Future<Uint8List?> showSignatureDialog(
  BuildContext context, {
  Uint8List? initialBytes,
}) {
  return showDialog<Uint8List>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _SignatureDialog(initialBytes: initialBytes),
  );
}

class _SignatureDialog extends StatefulWidget {
  const _SignatureDialog({this.initialBytes});

  final Uint8List? initialBytes;

  @override
  State<_SignatureDialog> createState() => _SignatureDialogState();
}

class _SignatureDialogState extends State<_SignatureDialog> {
  final _padKey = GlobalKey<SignaturePadState>();
  bool _hasSignature = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _hasSignature =
        widget.initialBytes != null && widget.initialBytes!.isNotEmpty;
  }

  Future<void> _save() async {
    if (!_hasSignature) {
      return;
    }
    setState(() => _saving = true);
    final bytes = await _padKey.currentState?.exportPng();
    if (!mounted) return;
    setState(() => _saving = false);
    if (bytes == null || bytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not save signature. Please try again.',
            style: GoogleFonts.exo2(),
          ),
        ),
      );
      return;
    }
    Navigator.of(context).pop(bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: AppColors.cream,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Digital signature',
              style: GoogleFonts.exo2(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.deepGreen,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Draw your signature in the box below, then tap Save.',
              style: GoogleFonts.exo2(
                fontSize: 13,
                height: 1.35,
                color: AppColors.deepGreen.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 16),
            if (widget.initialBytes != null &&
                widget.initialBytes!.isNotEmpty &&
                !_hasSignature)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    widget.initialBytes!,
                    height: 64,
                    fit: BoxFit.contain,
                    alignment: Alignment.centerLeft,
                  ),
                ),
              ),
            SignaturePad(
              key: _padKey,
              height: 220,
              showInlineClear: false,
              onChanged: (hasSignature) {
                setState(() => _hasSignature = hasSignature);
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: _saving
                      ? null
                      : () {
                          _padKey.currentState?.clear();
                          setState(() => _hasSignature = false);
                        },
                  child: Text(
                    'Clear',
                    style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.exo2(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _saving || !_hasSignature ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandPurple,
                    disabledBackgroundColor:
                        AppColors.brandPurple.withValues(alpha: 0.45),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Save',
                          style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
