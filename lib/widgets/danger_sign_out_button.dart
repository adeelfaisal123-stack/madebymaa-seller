import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// Outlined sign-out control using brand danger colors + logout icon.
class DangerSignOutButton extends StatelessWidget {
  const DangerSignOutButton({
    super.key,
    required this.onPressed,
    this.compact = false,
    this.label = 'Sign out',
  });

  final VoidCallback? onPressed;
  final bool compact;
  final String label;

  static const _danger = AppColors.kitchenOff;
  static const _dangerDeep = AppColors.kitchenOffDeep;

  @override
  Widget build(BuildContext context) {
    final style = OutlinedButton.styleFrom(
      foregroundColor: _danger,
      backgroundColor: _danger.withValues(alpha: 0.07),
      disabledForegroundColor: _danger.withValues(alpha: 0.4),
      disabledBackgroundColor: _danger.withValues(alpha: 0.04),
      side: BorderSide(
        color: onPressed != null
            ? _danger.withValues(alpha: 0.45)
            : _danger.withValues(alpha: 0.2),
        width: 1.4,
      ),
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 14, vertical: 10)
          : const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      minimumSize: compact ? null : const Size(double.infinity, 50),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
      ),
    );

    return OutlinedButton(
      onPressed: onPressed,
      style: style,
      child: Row(
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.logout_rounded,
            size: compact ? 18 : 20,
            color: onPressed != null ? _danger : _danger.withValues(alpha: 0.4),
          ),
          SizedBox(width: compact ? 6 : 10),
          Text(
            label,
            style: GoogleFonts.exo2(
              fontSize: compact ? 14 : 16,
              fontWeight: FontWeight.w700,
              color: onPressed != null ? _dangerDeep : _danger.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}
