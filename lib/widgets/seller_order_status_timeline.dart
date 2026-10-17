import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/seller_order.dart';
import '../theme/app_colors.dart';

/// Vertical order status timeline with SVG step icons.
class SellerOrderStatusTimeline extends StatelessWidget {
  const SellerOrderStatusTimeline({
    super.key,
    required this.steps,
    required this.currentIndex,
    required this.accentColor,
    this.deliveredActiveSubtitle,
    this.isCancelled = false,
  });

  final List<SellerOrderTimelineStep> steps;
  final int currentIndex;
  final Color accentColor;
  final String? deliveredActiveSubtitle;
  final bool isCancelled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 18, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCancelled
              ? AppColors.kitchenOff.withValues(alpha: 0.2)
              : accentColor.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SvgPicture.string(
                _timelineHeaderSvg,
                width: 18,
                height: 18,
                colorFilter: const ColorFilter.mode(
                  AppColors.brandPurple,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Order status',
                style: GoogleFonts.exo2(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < steps.length; i++)
            _OrderTimelineStepRow(
              step: steps[i],
              index: i,
              currentIndex: currentIndex,
              isLast: i == steps.length - 1,
              accentColor: accentColor,
              deliveredActiveSubtitle: deliveredActiveSubtitle,
              isCancelledOrder: isCancelled,
            ),
        ],
      ),
    );
  }
}

class _OrderTimelineStepRow extends StatelessWidget {
  const _OrderTimelineStepRow({
    required this.step,
    required this.index,
    required this.currentIndex,
    required this.isLast,
    required this.accentColor,
    this.deliveredActiveSubtitle,
    this.isCancelledOrder = false,
  });

  final SellerOrderTimelineStep step;
  final int index;
  final int currentIndex;
  final bool isLast;
  final Color accentColor;
  final String? deliveredActiveSubtitle;
  final bool isCancelledOrder;

  bool get _isCancelledStep => step.key == 'cancelled';

  bool get _isSkipped =>
      isCancelledOrder && !_isCancelledStep && index > 0 && index < currentIndex;

  bool get _isDone =>
      !_isCancelledStep && !_isSkipped && index < currentIndex;

  bool get _isActive => index == currentIndex;

  bool get _isUpcoming =>
      !_isCancelledStep && !isCancelledOrder && index > currentIndex;

  Color _iconColor() {
    if (_isCancelledStep) return AppColors.kitchenOff;
    if (_isSkipped) return AppColors.deepGreen.withValues(alpha: 0.25);
    if (_isUpcoming) return AppColors.deepGreen.withValues(alpha: 0.35);
    if (_isDone) return AppColors.kitchenOpen;
    return accentColor;
  }

  Color _ringColor() {
    if (_isCancelledStep) return AppColors.kitchenOff;
    if (_isSkipped || _isUpcoming) {
      return AppColors.deepGreen.withValues(alpha: 0.18);
    }
    return _iconColor();
  }

  Color _lineColor() {
    if (_isCancelledStep) return AppColors.deepGreen.withValues(alpha: 0.08);
    if (_isSkipped || _isUpcoming || index >= currentIndex) {
      return AppColors.deepGreen.withValues(alpha: 0.1);
    }
    return AppColors.kitchenOpen.withValues(alpha: 0.45);
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = _iconColor();
    final ringColor = _ringColor();
    final active = _isActive && !_isCancelledStep;
    final done = _isDone;
    final cancelledActive = _isCancelledStep && _isActive;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  width: cancelledActive ? 36 : (active ? 36 : 32),
                  height: cancelledActive ? 36 : (active ? 36 : 32),
                  decoration: BoxDecoration(
                    color: _isUpcoming || _isSkipped
                        ? Colors.transparent
                        : ringColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: ringColor,
                      width: cancelledActive || active ? 2.5 : 2,
                    ),
                    boxShadow: cancelledActive
                        ? [
                            BoxShadow(
                              color: AppColors.kitchenOff.withValues(alpha: 0.35),
                              blurRadius: 10,
                              spreadRadius: 0.5,
                            ),
                          ]
                        : active
                        ? [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.35),
                              blurRadius: 10,
                              spreadRadius: 0.5,
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: _isCancelledStep
                        ? SvgPicture.string(
                            _cancelledSvg,
                            width: cancelledActive ? 18 : 16,
                            height: cancelledActive ? 18 : 16,
                            colorFilter: ColorFilter.mode(
                              iconColor,
                              BlendMode.srcIn,
                            ),
                          )
                        : done
                        ? SvgPicture.string(
                            _checkSvg,
                            width: 16,
                            height: 16,
                            colorFilter: ColorFilter.mode(
                              iconColor,
                              BlendMode.srcIn,
                            ),
                          )
                        : SvgPicture.string(
                            _iconSvgForKey(step.key),
                            width: active ? 18 : 16,
                            height: active ? 18 : 16,
                            colorFilter: ColorFilter.mode(
                              iconColor,
                              BlendMode.srcIn,
                            ),
                          ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2.5,
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: _lineColor(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                top: 6,
                bottom: isLast ? 0 : 22,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: GoogleFonts.exo2(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _isCancelledStep
                          ? AppColors.kitchenOff
                          : _isUpcoming || _isSkipped
                              ? AppColors.deepGreen.withValues(alpha: 0.38)
                              : AppColors.deepGreen,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _subtitleForStep(step.key, done, active, cancelledActive),
                    style: GoogleFonts.exo2(
                      fontSize: 12,
                      height: 1.35,
                      color: _isCancelledStep
                          ? AppColors.kitchenOff.withValues(alpha: 0.75)
                          : _isUpcoming || _isSkipped
                              ? AppColors.deepGreen.withValues(alpha: 0.32)
                              : AppColors.deepGreen.withValues(alpha: 0.58),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _subtitleForStep(
    String key,
    bool done,
    bool active,
    bool cancelledActive,
  ) {
    if (key == 'cancelled') {
      return cancelledActive ? 'Order was cancelled' : 'Cancelled';
    }
    if (_isSkipped) return 'Not reached';
    if (done) return 'Completed';
    if (active && key == 'delivered') {
      return deliveredActiveSubtitle ?? 'Congratulations, you have earned this order amount';
    }
    if (active) return 'In progress now';
    return switch (key) {
      'pending' => 'Waiting for kitchen confirmation',
      'accepted' => 'Kitchen accepted the order',
      'ready_to_pick_up' => 'Packed and ready for rider',
      'picked_up' => 'Rider collected the order',
      'on_way' => 'Heading to customer',
      'delivered' => 'Handed to customer',
      _ => 'Upcoming',
    };
  }
}

String _iconSvgForKey(String key) {
  return switch (key) {
    'accepted' => _acceptedSvg,
    'ready_to_pick_up' => _readySvg,
    'picked_up' => _pickedUpSvg,
    'on_way' => _onWaySvg,
    'delivered' => _deliveredSvg,
    _ => _placedSvg,
  };
}

const _timelineHeaderSvg = '''
<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M4 6h16M4 12h10M4 18h14" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
</svg>
''';

const _placedSvg = '''
<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M9 5H7a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2h-2" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
  <rect x="9" y="3" width="6" height="4" rx="1" stroke="currentColor" stroke-width="1.8"/>
  <path d="M9 12h6M9 16h4" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
</svg>
''';

const _acceptedSvg = '''
<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M9 11.5 11 13.5 15 9.5" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18Z" stroke="currentColor" stroke-width="1.8"/>
</svg>
''';

const _readySvg = '''
<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M21 8.5 12 3 3 8.5V19a1 1 0 0 0 1 1h16a1 1 0 0 0 1-1V8.5Z" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/>
  <path d="M3 8.5 12 14l9-5.5M9 21v-7h6v7" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
''';

const _pickedUpSvg = '''
<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M6 2 3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4H6Z" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/>
  <path d="M3 6h18M16 10a4 4 0 0 1-8 0" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
</svg>
''';

const _onWaySvg = '''
<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <circle cx="7" cy="17" r="2" stroke="currentColor" stroke-width="1.8"/>
  <circle cx="17" cy="17" r="2" stroke="currentColor" stroke-width="1.8"/>
  <path d="M5 17h-.5a1.5 1.5 0 0 1 0-3H6l2.2-6.6A2 2 0 0 1 10.1 6H16v8.5" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M16 6h2.5l1.5 3H16" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
''';

const _deliveredSvg = '''
<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M3 10.5 12 4l9 6.5V19a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-8.5Z" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/>
  <path d="M9 21v-6h6v6" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M9 12.5 11 14.5 15 10.5" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
''';

const _checkSvg = '''
<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="m5 12.5 4 4L19 7.5" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
''';

const _cancelledSvg = '''
<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <circle cx="12" cy="12" r="9" stroke="currentColor" stroke-width="1.8"/>
  <path d="m8 8 8 8M16 8l-8 8" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
</svg>
''';
