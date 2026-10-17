import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../utils/app_system_ui.dart';

/// Placeholder for buyer–seller chat; wire to messaging API when available.
class SellerMessagesScreen extends StatelessWidget {
  const SellerMessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.deepGreen),
        title: Text(
          'Messages',
          style: GoogleFonts.exo2(
            fontWeight: FontWeight.w800,
            color: AppColors.deepGreen,
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          AppSystemUi.bottomInset(context, 24),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.brandPurple.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 40,
                color: AppColors.brandPurple,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No messages yet',
              style: GoogleFonts.exo2(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.deepGreen,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'When customers message you about orders, conversations will appear here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.exo2(
                fontSize: 14,
                height: 1.45,
                color: AppColors.deepGreen.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
