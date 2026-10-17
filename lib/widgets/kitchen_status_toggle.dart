import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// Pill toggle for kitchen open / closed.
class KitchenStatusToggle extends StatefulWidget {
  const KitchenStatusToggle({
    super.key,
    required this.isOpen,
    required this.onChanged,
    this.embeddedInHero = false,
  });

  final bool isOpen;
  final ValueChanged<bool> onChanged;

  /// Frosted style for inside the green/red hero card.
  final bool embeddedInHero;

  static const width = 128.0;
  static const height = 44.0;
  static const embeddedWidth = 116.0;
  static const embeddedHeight = 48.0;
  static const thumbSize = 34.0;
  static const embeddedThumbSize = 36.0;

  @override
  State<KitchenStatusToggle> createState() => _KitchenStatusToggleState();
}

class _KitchenStatusToggleState extends State<KitchenStatusToggle>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant KitchenStatusToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
  }

  void _syncPulse() {
    if (widget.isOpen) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.mediumImpact();
    widget.onChanged(!widget.isOpen);
  }

  @override
  Widget build(BuildContext context) {
    return widget.embeddedInHero ? _buildEmbedded() : _buildStandalone();
  }

  Widget _buildEmbedded() {
    final open = widget.isOpen;
    const thumb = KitchenStatusToggle.embeddedThumbSize;
    const gap = 4.0;
    final labelInset = thumb + gap + 2;
    const w = KitchenStatusToggle.embeddedWidth;
    const h = KitchenStatusToggle.embeddedHeight;

    return Semantics(
      button: true,
      label: open ? 'Kitchen open' : 'Kitchen closed',
      child: GestureDetector(
        onTap: _toggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
          width: w,
          height: h,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: Colors.white.withValues(alpha: open ? 0.22 : 0.14),
            border: Border.all(
              color: Colors.white.withValues(alpha: open ? 0.55 : 0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOutCubic,
                left: open ? gap : labelInset,
                right: open ? labelInset : gap,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Text(
                    open ? 'LIVE' : 'OFF',
                    style: GoogleFonts.exo2(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOutBack,
                left: open ? null : gap,
                right: open ? gap : null,
                top: 0,
                bottom: 0,
                child: _Thumb(
                  isOpen: open,
                  pulse: _pulse,
                  size: thumb,
                  onHero: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStandalone() {
    final open = widget.isOpen;
    const thumb = KitchenStatusToggle.thumbSize;
    const gap = 5.0;
    final labelInset = thumb + gap + 4;

    return Semantics(
      button: true,
      label: open ? 'Kitchen open' : 'Kitchen closed',
      child: GestureDetector(
        onTap: _toggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
          width: KitchenStatusToggle.width,
          height: KitchenStatusToggle.height,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: open
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.kitchenOpen,
                      AppColors.kitchenOpenDeep,
                    ],
                  )
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white, AppColors.cream],
                  ),
            border: Border.all(
              color: open
                  ? Colors.white.withValues(alpha: 0.35)
                  : AppColors.deepGreen.withValues(alpha: 0.12),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: open
                    ? AppColors.kitchenOpen.withValues(alpha: 0.45)
                    : Colors.black.withValues(alpha: 0.06),
                blurRadius: open ? 16 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 380),
                    curve: Curves.easeOutCubic,
                    left: open ? gap : labelInset,
                    right: open ? labelInset : gap,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Text(
                        open ? 'OPEN' : 'OFF',
                        maxLines: 1,
                        overflow: TextOverflow.visible,
                        softWrap: false,
                        style: GoogleFonts.exo2(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: open
                              ? Colors.white.withValues(alpha: 0.95)
                              : AppColors.terracotta,
                        ),
                      ),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 380),
                    curve: Curves.easeOutBack,
                    left: open ? null : gap,
                    right: open ? gap : null,
                    top: 0,
                    bottom: 0,
                    child: _Thumb(isOpen: open, pulse: _pulse),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Toggle area inside the home "Kitchen is live" hero card.
class KitchenLiveToggleDock extends StatelessWidget {
  const KitchenLiveToggleDock({
    super.key,
    required this.isOpen,
    required this.onChanged,
    this.enabled = true,
    this.loading = false,
  });

  final bool isOpen;
  final ValueChanged<bool> onChanged;
  final bool enabled;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !enabled || loading,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: loading
            ? const SizedBox(
                width: 116,
                height: 48,
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  ),
                ),
              )
            : KitchenStatusToggle(
                isOpen: isOpen,
                onChanged: onChanged,
                embeddedInHero: true,
              ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.isOpen,
    required this.pulse,
    this.size = KitchenStatusToggle.thumbSize,
    this.onHero = false,
  });

  final bool isOpen;
  final Animation<double> pulse;
  final double size;
  final bool onHero;

  @override
  Widget build(BuildContext context) {
    final iconColor = onHero
        ? (isOpen ? AppColors.kitchenOpenDeep : AppColors.kitchenOffDeep)
        : (isOpen ? AppColors.kitchenOpen : AppColors.terracotta);

    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) {
        final glow = isOpen ? 0.25 + pulse.value * 0.35 : 0.0;
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: isOpen
                    ? AppColors.amberGlow.withValues(alpha: glow)
                    : AppColors.terracotta.withValues(alpha: 0.2),
                blurRadius: isOpen ? 12 : 8,
                spreadRadius: isOpen ? 1 : 0,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: child,
        );
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            isOpen
                ? Icons.soup_kitchen_rounded
                : Icons.power_settings_new_rounded,
            size: onHero ? 21 : 20,
            color: iconColor,
          ),
          if (isOpen)
            Positioned(
              top: size * 0.2,
              right: size * 0.2,
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: const Color(0xFF4ADE80),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
