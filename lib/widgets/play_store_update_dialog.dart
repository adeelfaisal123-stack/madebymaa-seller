import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:in_app_update/in_app_update.dart';

import '../theme/app_colors.dart';

/// Prompts the user to update from Google Play when a newer build is available.
Future<bool?> showPlayStoreUpdateDialog(
  BuildContext context, {
  required AppUpdateInfo updateInfo,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _PlayStoreUpdateDialog(updateInfo: updateInfo),
  );
}

class _PlayStoreUpdateDialog extends StatelessWidget {
  const _PlayStoreUpdateDialog({required this.updateInfo});

  final AppUpdateInfo updateInfo;

  @override
  Widget build(BuildContext context) {
    final immediate = updateInfo.immediateUpdateAllowed;
    final subtitle = immediate
        ? 'A new version is available on Google Play. Update now to get the latest fixes and features.'
        : 'A new version is available on Google Play. You can update now or continue and update later.';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        'Update available',
        style: GoogleFonts.exo2(fontWeight: FontWeight.w800),
      ),
      content: Text(
        subtitle,
        style: GoogleFonts.exo2(
          fontSize: 14,
          height: 1.4,
          color: AppColors.deepGreen.withValues(alpha: 0.85),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Later',
            style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.brandPurple,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            'Update now',
            style: GoogleFonts.exo2(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
