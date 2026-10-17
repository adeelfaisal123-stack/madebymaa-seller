import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../utils/app_system_ui.dart';

/// Branded floating toasts (danger / success / warning).
abstract final class AppToast {
  static const _duration = Duration(seconds: 3);
  static const _longDuration = Duration(seconds: 4);

  /// API failures, auth errors, network issues.
  static void danger(
    BuildContext context,
    String message, {
    double bottomPadding = 20,
    Duration? duration,
  }) {
    _show(
      context,
      message: message,
      icon: Icons.error_outline_rounded,
      gradient: const [AppColors.kitchenOff, AppColors.kitchenOffDeep],
      accent: const Color(0xFFFF8A80),
      bottomPadding: bottomPadding,
      duration: duration ?? _longDuration,
    );
  }

  /// Missing fields, soft validation hints.
  static void warning(
    BuildContext context,
    String message, {
    double bottomPadding = 20,
  }) {
    _show(
      context,
      message: message,
      icon: Icons.info_outline_rounded,
      gradient: const [Color(0xFFC65D1A), Color(0xFF9A4510)],
      accent: AppColors.bootstrapWarning,
      bottomPadding: bottomPadding,
      duration: _duration,
    );
  }

  /// Confirmations (e.g. kitchen open / off).
  static void success(
    BuildContext context,
    String message, {
    double bottomPadding = 20,
    Color? background,
  }) {
    _show(
      context,
      message: message,
      icon: Icons.check_circle_outline_rounded,
      gradient: background != null
          ? [background, background]
          : const [AppColors.kitchenOpen, AppColors.kitchenOpenDeep],
      accent: const Color(0xFF86EFAC),
      bottomPadding: bottomPadding,
      duration: _duration,
    );
  }

  static void _show(
    BuildContext context, {
    required String message,
    required IconData icon,
    required List<Color> gradient,
    required Color accent,
    required double bottomPadding,
    required Duration duration,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          elevation: 0,
          backgroundColor: Colors.transparent,
          padding: EdgeInsets.zero,
          margin: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            AppSystemUi.bottomInset(context, bottomPadding),
          ),
          duration: duration,
          content: _ToastCard(
            message: message,
            icon: icon,
            gradient: gradient,
            accent: accent,
          ),
        ),
      );
  }
}

class _ToastCard extends StatelessWidget {
  const _ToastCard({
    required this.message,
    required this.icon,
    required this.gradient,
    required this.accent,
  });

  final String message;
  final IconData icon;
  final List<Color> gradient;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withValues(alpha: 0.45),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                shape: BoxShape.circle,
                border: Border.all(
                  color: accent.withValues(alpha: 0.55),
                  width: 1.5,
                ),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.exo2(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  color: Colors.white,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
