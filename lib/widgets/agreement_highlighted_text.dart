import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../services/seller_agreement_personalizer.dart';

/// Renders agreement text with seller-filled values in bold and underlined.
class AgreementHighlightedText extends StatelessWidget {
  const AgreementHighlightedText({
    super.key,
    required this.segments,
    this.fontSize = 13,
    this.lineHeight = 1.55,
  });

  final List<AgreementTextSegment> segments;
  final double fontSize;
  final double lineHeight;

  @override
  Widget build(BuildContext context) {
    final baseColor = AppColors.deepGreen.withValues(alpha: 0.82);
    final baseStyle = GoogleFonts.exo2(
      fontSize: fontSize,
      height: lineHeight,
      color: baseColor,
    );
    final highlightStyle = baseStyle.copyWith(
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: baseColor,
      decorationThickness: 1.2,
    );

    return Text.rich(
      TextSpan(
        children: [
          for (final segment in segments)
            TextSpan(
              text: segment.text,
              style: segment.highlight ? highlightStyle : baseStyle,
            ),
        ],
      ),
    );
  }
}
