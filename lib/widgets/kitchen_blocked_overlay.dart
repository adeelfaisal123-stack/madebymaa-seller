import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// Full-screen notice when the kitchen has been blocked by an administrator.
class KitchenBlockedOverlay extends StatelessWidget {
  const KitchenBlockedOverlay({
    super.key,
    this.message =
        'Your kitchen has been blocked. Please contact the administrator.',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cream,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.kitchenOff.withValues(alpha: 0.12),
                    border: Border.all(color: AppColors.kitchenOff, width: 2),
                  ),
                  child: const Icon(
                    Icons.block_rounded,
                    size: 44,
                    color: AppColors.kitchenOff,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Kitchen blocked',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.exo2(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.deepGreen,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.exo2(
                    fontSize: 15,
                    height: 1.45,
                    color: AppColors.deepGreen.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'You cannot manage dishes, hours, or orders until your kitchen is unblocked.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.exo2(
                    fontSize: 13,
                    color: AppColors.deepGreen.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
