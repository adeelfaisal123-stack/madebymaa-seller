import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

class SellerNavItem {
  const SellerNavItem({
    required this.icon,
    required this.activeIcon,
    this.label,
    this.badge,
  });

  final IconData icon;
  final IconData activeIcon;
  final String? label;
  final int? badge;
}

/// Full-width bottom bar with center notch, gradient hub, and animated tabs.
class SellerBottomNav extends StatefulWidget {
  const SellerBottomNav({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onChanged,
    this.centerIndex = 2,
  }) : assert(items.length == 5, 'SellerBottomNav expects exactly 5 items');

  final int currentIndex;
  final List<SellerNavItem> items;
  final ValueChanged<int> onChanged;
  final int centerIndex;

  @override
  State<SellerBottomNav> createState() => _SellerBottomNavState();
}

class _SellerBottomNavState extends State<SellerBottomNav>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  static const _barHeight = 68.0;
  static const _hubOuter = 58.0;
  static const _hubRise = 20.0;
  static const _notchRadius = 34.0;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final centerItem = widget.items[widget.centerIndex];

    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return SizedBox(
        width: double.infinity,
        height: _barHeight + _hubRise + bottomInset,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipPath(
                clipper: _NotchedBarClipper(notchRadius: _notchRadius),
                child: Container(
                  height: _barHeight + bottomInset,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white,
                        AppColors.cream.withValues(alpha: 0.95),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.brandPurple.withValues(alpha: 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, -8),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              width: 1,
                              color: AppColors.brandPurple.withValues(
                                alpha: 0.08,
                              ),
                            ),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.97),
                              AppColors.cream.withValues(alpha: 0.88),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: _barHeight + bottomInset - 1,
              child: IgnorePointer(
                child: CustomPaint(
                  size: Size(MediaQuery.sizeOf(context).width, 3),
                  painter: _TopAccentPainter(
                    notchRadius: _notchRadius,
                    color: AppColors.brandPurple.withValues(alpha: 0.35),
                  ),
                ),
              ),
            ),
            // Hub below side tabs so taps pass through the center gap only.
            Positioned(
              left: 0,
              right: 0,
              bottom: _barHeight + bottomInset + _hubRise - _hubOuter,
              child: Center(
                child: _CenterHub(
                  item: centerItem,
                  selected: widget.currentIndex == widget.centerIndex,
                  pulse: _pulse,
                  outerSize: _hubOuter,
                  onTap: () => widget.onChanged(widget.centerIndex),
                ),
              ),
            ),
            if (centerItem.label != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 8 + bottomInset,
                child: IgnorePointer(
                  child: Center(
                    child: Text(
                      centerItem.label!,
                      style: GoogleFonts.exo2(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                        color: widget.currentIndex == widget.centerIndex
                            ? AppColors.brandPurple
                            : AppColors.deepGreen.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ),
            // Side tabs on top so their hit targets are not blocked.
            Positioned(
              left: 4,
              right: 4,
              bottom: 8 + bottomInset,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _SideTab(
                      item: widget.items[0],
                      selected: widget.currentIndex == 0,
                      onTap: () => widget.onChanged(0),
                    ),
                  ),
                  Expanded(
                    child: _SideTab(
                      item: widget.items[1],
                      selected: widget.currentIndex == 1,
                      onTap: () => widget.onChanged(1),
                    ),
                  ),
                  SizedBox(width: _hubOuter + 12),
                  Expanded(
                    child: _SideTab(
                      item: widget.items[3],
                      selected: widget.currentIndex == 3,
                      onTap: () => widget.onChanged(3),
                    ),
                  ),
                  Expanded(
                    child: _SideTab(
                      item: widget.items[4],
                      selected: widget.currentIndex == 4,
                      onTap: () => widget.onChanged(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
    );
  }
}

class _NotchedBarClipper extends CustomClipper<Path> {
  _NotchedBarClipper({required this.notchRadius});

  final double notchRadius;

  @override
  Path getClip(Size size) {
    final w = size.width;
    final cx = w / 2;
    final r = notchRadius;
    const corner = 22.0;

    return Path()
      ..moveTo(0, corner)
      ..quadraticBezierTo(0, 0, corner, 0)
      ..lineTo(cx - r - 14, 0)
      ..cubicTo(cx - r, 0, cx - r * 0.55, r * 0.55, cx, r * 0.85)
      ..cubicTo(cx + r * 0.55, r * 0.55, cx + r, 0, cx + r + 14, 0)
      ..lineTo(w - corner, 0)
      ..quadraticBezierTo(w, 0, w, corner)
      ..lineTo(w, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant _NotchedBarClipper oldClipper) =>
      oldClipper.notchRadius != notchRadius;
}

class _TopAccentPainter extends CustomPainter {
  _TopAccentPainter({required this.notchRadius, required this.color});

  final double notchRadius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final cx = w / 2;
    final r = notchRadius;

    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0),
          color,
          AppColors.amberGlow.withValues(alpha: 0.6),
          color,
          color.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, size.height))
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(cx - r - 20, size.height)
      ..cubicTo(
        cx - r,
        size.height,
        cx - r * 0.5,
        size.height - r * 0.35,
        cx,
        size.height - r * 0.5,
      )
      ..cubicTo(
        cx + r * 0.5,
        size.height - r * 0.35,
        cx + r,
        size.height,
        cx + r + 20,
        size.height,
      )
      ..lineTo(w, size.height);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TopAccentPainter oldDelegate) => false;
}

class _SideTab extends StatelessWidget {
  const _SideTab({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final SellerNavItem item;
  final bool selected;
  final VoidCallback onTap;

  static const _tabHeight = 54.0;
  static const _iconSlot = 28.0;
  static const _labelSlot = 22.0;

  @override
  Widget build(BuildContext context) {
    final labelStyle = GoogleFonts.exo2(
      fontSize: 9.5,
      height: 1.0,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      letterSpacing: selected ? 0.15 : 0,
      color: selected
          ? AppColors.brandPurple
          : AppColors.deepGreen.withValues(alpha: 0.42),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: AppColors.brandPurple.withValues(alpha: 0.1),
        highlightColor: AppColors.brandPurple.withValues(alpha: 0.05),
        child: SizedBox(
          height: _tabHeight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SizedBox(
                height: _iconSlot,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    width: selected ? 42 : 38,
                    height: _iconSlot,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(11),
                      gradient: selected
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.brandPurple.withValues(alpha: 0.18),
                                AppColors.brandPurple.withValues(alpha: 0.08),
                              ],
                            )
                          : null,
                      border: Border.all(
                        color: selected
                            ? AppColors.brandPurple.withValues(alpha: 0.35)
                            : AppColors.deepGreen.withValues(alpha: 0.08),
                        width: 1.2,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Icon(
                          selected ? item.activeIcon : item.icon,
                          size: selected ? 20 : 19,
                          color: selected
                              ? AppColors.brandPurple
                              : AppColors.deepGreen.withValues(alpha: 0.38),
                        ),
                        if (item.badge != null && item.badge! > 0)
                          Positioned(
                            top: 2,
                            right: 4,
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: AppColors.terracotta,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: _labelSlot,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      width: selected ? 14 : 0,
                      height: selected ? 2 : 0,
                      margin: const EdgeInsets.only(bottom: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: selected
                            ? const LinearGradient(
                                colors: [
                                  AppColors.brandPurple,
                                  AppColors.amberGlow,
                                ],
                              )
                            : null,
                      ),
                    ),
                    if (item.label != null)
                      Text(
                        item.label!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: labelStyle,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CenterHub extends StatelessWidget {
  const _CenterHub({
    required this.item,
    required this.selected,
    required this.pulse,
    required this.outerSize,
    required this.onTap,
  });

  final SellerNavItem item;
  final bool selected;
  final Animation<double> pulse;
  final double outerSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final innerSize = outerSize - 14;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: outerSize,
            height: outerSize,
            child: AnimatedBuilder(
              animation: pulse,
              builder: (context, child) {
                final glow = selected ? 0.12 + pulse.value * 0.14 : 0.08;
                return Container(
                  width: outerSize,
                  height: outerSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.brandPurple.withValues(alpha: glow),
                        blurRadius: 22,
                        spreadRadius: selected ? 2 : 0,
                      ),
                      BoxShadow(
                        color: AppColors.amberGlow.withValues(
                          alpha: selected ? 0.15 : 0.05,
                        ),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: child,
                );
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: outerSize,
                    height: outerSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        width: 2.5,
                        color: selected
                            ? AppColors.brandPurple
                            : AppColors.brandPurple.withValues(alpha: 0.45),
                      ),
                      color: Colors.white,
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    width: innerSize,
                    height: innerSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: selected
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.brandPurple,
                                AppColors.brandPurpleDeep,
                              ],
                            )
                          : LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white,
                                AppColors.cream,
                              ],
                            ),
                      border: Border.all(
                        color: Colors.white.withValues(
                          alpha: selected ? 0.35 : 0.9,
                        ),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      selected ? item.activeIcon : item.icon,
                      size: 26,
                      color:
                          selected ? Colors.white : AppColors.brandPurple,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
