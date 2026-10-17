import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// Horizontal swipe control — drag the thumb to the end to confirm an action.
class SwipeToConfirmButton extends StatefulWidget {
  const SwipeToConfirmButton({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.loading = false,
    this.loadingLabel = 'Working…',
    this.enabled = true,
    this.trackColor = AppColors.kitchenOpen,
    this.height = 52,
  });

  final String label;
  final VoidCallback onConfirmed;
  final bool loading;
  final String loadingLabel;
  final bool enabled;
  final Color trackColor;
  final double height;

  static const _thumbSize = 44.0;
  static const _horizontalPadding = 4.0;

  @override
  State<SwipeToConfirmButton> createState() => _SwipeToConfirmButtonState();
}

class _SwipeToConfirmButtonState extends State<SwipeToConfirmButton> {
  double _dragOffset = 0;
  bool _completed = false;

  @override
  void didUpdateWidget(covariant SwipeToConfirmButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loading && !widget.loading && !widget.enabled) {
      _reset();
    }
    if (oldWidget.loading && !widget.loading && widget.enabled) {
      _reset();
    }
  }

  void _reset() {
    if (_dragOffset == 0 && !_completed) return;
    setState(() {
      _dragOffset = 0;
      _completed = false;
    });
  }

  double _maxDrag(double trackWidth) {
    return trackWidth -
        SwipeToConfirmButton._thumbSize -
        (SwipeToConfirmButton._horizontalPadding * 2);
  }

  void _onDragUpdate(double delta, double maxDrag) {
    if (!widget.enabled || widget.loading || _completed) return;
    setState(() {
      _dragOffset = (_dragOffset + delta).clamp(0, maxDrag);
    });
  }

  void _onDragEnd(double maxDrag) {
    if (!widget.enabled || widget.loading || _completed) return;

    if (_dragOffset >= maxDrag * 0.82) {
      setState(() {
        _dragOffset = maxDrag;
        _completed = true;
      });
      HapticFeedback.mediumImpact();
      widget.onConfirmed();
      return;
    }

    HapticFeedback.selectionClick();
    setState(() => _dragOffset = 0);
  }

  @override
  Widget build(BuildContext context) {
    final inactive = !widget.enabled || widget.loading;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxDrag = _maxDrag(constraints.maxWidth);
        final progress = maxDrag <= 0 ? 0.0 : (_dragOffset / maxDrag).clamp(0.0, 1.0);

        return AnimatedContainer(
          duration: _completed || widget.loading
              ? Duration.zero
              : const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          height: widget.height,
          decoration: BoxDecoration(
            color: inactive
                ? widget.trackColor.withValues(alpha: 0.45)
                : Color.lerp(
                    widget.trackColor.withValues(alpha: 0.18),
                    widget.trackColor,
                    progress,
                  ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.trackColor.withValues(alpha: inactive ? 0.2 : 0.35),
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: (1 - progress * 1.4).clamp(0.0, 1.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.label,
                      style: GoogleFonts.exo2(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.deepGreen.withValues(alpha: 0.72),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.double_arrow_rounded,
                      size: 18,
                      color: AppColors.deepGreen.withValues(alpha: 0.45),
                    ),
                  ],
                ),
              ),
              if (widget.loading)
                Text(
                  widget.loadingLabel,
                  style: GoogleFonts.exo2(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                )
              else
                AnimatedPositioned(
                  duration: _completed
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  left: SwipeToConfirmButton._horizontalPadding + _dragOffset,
                  top: (widget.height - SwipeToConfirmButton._thumbSize) / 2,
                  child: GestureDetector(
                    onHorizontalDragUpdate: inactive
                        ? null
                        : (details) =>
                            _onDragUpdate(details.delta.dx, maxDrag),
                    onHorizontalDragEnd: inactive
                        ? null
                        : (_) => _onDragEnd(maxDrag),
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        width: SwipeToConfirmButton._thumbSize,
                        height: SwipeToConfirmButton._thumbSize,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          _completed
                              ? Icons.task_alt_rounded
                              : Icons.chevron_right_rounded,
                          color: widget.trackColor,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
