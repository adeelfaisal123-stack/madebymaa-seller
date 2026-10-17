import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/optica2_api.dart';
import '../services/seller_auth_navigation.dart';
import '../services/seller_push_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_toast.dart';
import '../widgets/danger_sign_out_button.dart';
import 'phone_auth_screen.dart';

/// Shown when KYC documents are submitted and `seller_kyc_status` is pending.
class SellerKycPendingScreen extends StatefulWidget {
  const SellerKycPendingScreen({
    super.key,
    required this.sellerId,
    required this.phoneE164,
    this.message,
  });

  final int sellerId;
  final String phoneE164;
  final String? message;

  @override
  State<SellerKycPendingScreen> createState() => _SellerKycPendingScreenState();
}

class _SellerKycPendingScreenState extends State<SellerKycPendingScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _optica2 = Optica2Api();
  bool _refreshing = false;
  String? _statusMessage;

  AnimationController? _enter;
  AnimationController? _pulse;
  AnimationController? _shimmer;
  AnimationController? _orbit;

  static const _defaultMessage =
      'Signup completed. Please wait for admin approval.';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _statusMessage = widget.message;
    _initAnimations();
    WidgetsBinding.instance.addPostFrameCallback((_) => _registerForPush());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _registerForPush();
    }
  }

  Future<void> _registerForPush() async {
    await SellerPushService.registerDevice(
      api: _optica2,
      phoneE164: widget.phoneE164,
      sellerId: widget.sellerId,
    );
  }

  /// Hot reload keeps [State] but skips [initState]; re-create controllers safely.
  @override
  void reassemble() {
    super.reassemble();
    _disposeAnimations();
    _initAnimations();
  }

  void _initAnimations() {
    if (_pulse != null) return;

    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();

    _orbit = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 9000),
    )..repeat();
  }

  void _disposeAnimations() {
    _enter?.dispose();
    _pulse?.dispose();
    _shimmer?.dispose();
    _orbit?.dispose();
    _enter = null;
    _pulse = null;
    _shimmer = null;
    _orbit = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _optica2.close();
    _disposeAnimations();
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    setState(() => _refreshing = true);
    try {
      final result = await _optica2.fetchSellerKycStatus(
        phoneE164: widget.phoneE164,
        sellerId: widget.sellerId,
      );
      if (!mounted) return;

      setState(() => _statusMessage = result.message);

      if (result.canLogin) {
        SellerAuthNavigation.openHome(context);
        return;
      }

      if (result.needsKycForm) {
        SellerAuthNavigation.openKyc(
          context,
          sellerId: result.sellerId ?? widget.sellerId,
          phoneE164: widget.phoneE164,
          resumeToHomeOnComplete: true,
        );
      }
    } on Optica2ApiException catch (e) {
      if (!mounted) return;
      AppToast.danger(context, e.message);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cream,
        title: Text(
          'Sign out?',
          style: GoogleFonts.exo2(
            fontWeight: FontWeight.w800,
            color: AppColors.deepGreen,
          ),
        ),
        content: Text(
          'You can sign back in after your verification is approved.',
          style: GoogleFonts.exo2(
            height: 1.45,
            color: AppColors.deepGreen.withValues(alpha: 0.75),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.exo2()),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.logout_rounded, size: 20),
            label: Text('Sign out', style: GoogleFonts.exo2()),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.kitchenOff,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    await SellerAuthNavigation.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const PhoneAuthScreen()),
      (route) => false,
    );
  }

  TextStyle _exo(
    double size,
    FontWeight weight, {
    Color? color,
    double height = 1.2,
  }) {
    return GoogleFonts.exo2(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: size > 20 ? 0.3 : 0.15,
    );
  }

  Widget _fadeSlide({
    required double start,
    required double end,
    required Widget child,
  }) {
    final enter = _enter!;
    return AnimatedBuilder(
      animation: enter,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(
          ((enter.value - start) / (end - start)).clamp(0.0, 1.0),
        );
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - t)),
            child: child,
          ),
        );
      },
    );
  }

  Widget _hero() {
    final pulseCtrl = _pulse!;
    final orbitCtrl = _orbit!;
    return AnimatedBuilder(
      animation: Listenable.merge([pulseCtrl, orbitCtrl, _shimmer!]),
      builder: (context, _) {
        final pulse = 0.92 + 0.08 * pulseCtrl.value;
        final glow = 0.35 + 0.25 * pulseCtrl.value;

        return SizedBox(
          width: 180,
          height: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: orbitCtrl.value * 2 * math.pi,
                child: CustomPaint(
                  size: const Size(168, 168),
                  painter: _OrbitRingPainter(progress: orbitCtrl.value),
                ),
              ),
              Container(
                width: 132 * pulse,
                height: 132 * pulse,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.brandPurple.withValues(alpha: glow),
                      AppColors.brandPurple.withValues(alpha: 0.04),
                    ],
                  ),
                ),
              ),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.brandPurple,
                      AppColors.brandPurpleDeep,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brandPurple.withValues(alpha: 0.45),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.28),
                    width: 2,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      size: 42,
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                    Positioned(
                      right: 20,
                      bottom: 20,
                      child: Transform.scale(
                        scale: 0.85 + 0.15 * pulseCtrl.value,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.amberGlow,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.hourglass_top_rounded,
                            size: 14,
                            color: AppColors.brandPurpleDeep,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _shimmerTitle(String text) {
    final shimmerCtrl = _shimmer!;
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) {
        final start = -1.0 + 2.2 * shimmerCtrl.value;
        return LinearGradient(
          colors: [
            AppColors.deepGreen,
            AppColors.brandPurple,
            AppColors.deepGreen,
          ],
          stops: const [0.0, 0.5, 1.0],
          begin: Alignment(start, 0),
          end: Alignment(start + 1.0, 0),
        ).createShader(bounds);
      },
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: _exo(30, FontWeight.w800, color: AppColors.deepGreen),
      ),
    );
  }

  Widget _timeline() {
    const steps = [
      _TimelineStep(
        label: 'Information submitted',
        icon: Icons.check_circle_rounded,
        state: _StepState.done,
      ),
      _TimelineStep(
        label: 'Under review',
        icon: Icons.manage_search_rounded,
        state: _StepState.active,
      ),
      _TimelineStep(
        label: 'Kitchen goes live',
        icon: Icons.storefront_rounded,
        state: _StepState.upcoming,
      ),
    ];

    return Column(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          _TimelineTile(
            step: steps[i],
            pulse: _pulse!,
            isLast: i == steps.length - 1,
          ),
          if (i < steps.length - 1)
            AnimatedBuilder(
              animation: _pulse!,
              builder: (context, _) {
                return Container(
                  width: 2,
                  height: 22,
                  margin: const EdgeInsets.only(left: 19),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(1),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.brandPurple.withValues(alpha: 0.7),
                        AppColors.brandPurple.withValues(
                          alpha: 0.15 + 0.2 * _pulse!.value,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    _initAnimations();
    final message = _statusMessage ?? _defaultMessage;
    final pulseCtrl = _pulse!;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.brandPurple.withValues(alpha: 0.08),
                  AppColors.cream,
                  AppColors.cream,
                ],
              ),
            ),
          ),
          AnimatedBuilder(
            animation: pulseCtrl,
            builder: (context, _) {
              return CustomPaint(
                painter: _AmbientBlobPainter(phase: pulseCtrl.value),
                size: Size.infinite,
              );
            },
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      children: [
                  _fadeSlide(
                    start: 0,
                    end: 0.25,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Verification',
                        style: _exo(
                          18,
                          FontWeight.w700,
                          color: AppColors.deepGreen,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _fadeSlide(
                    start: 0.08,
                    end: 0.45,
                    child: _hero(),
                  ),
                  const SizedBox(height: 20),
                  _fadeSlide(
                    start: 0.2,
                    end: 0.55,
                    child: _shimmerTitle('Please wait'),
                  ),
                  const SizedBox(height: 10),
                  _fadeSlide(
                    start: 0.28,
                    end: 0.62,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brandPurple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.brandPurple.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 8,
                            height: 8,
                            child: AnimatedBuilder(
                              animation: pulseCtrl,
                              builder: (context, _) {
                                return DecoratedBox(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.brandPurple.withValues(
                                      alpha: 0.5 + 0.5 * pulseCtrl.value,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Pending approval',
                            style: _exo(
                              13,
                              FontWeight.w700,
                              color: AppColors.brandPurple,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _fadeSlide(
                    start: 0.35,
                    end: 0.72,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppColors.brandPurple.withValues(alpha: 0.12),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.brandPurple.withValues(
                              alpha: 0.08,
                            ),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Text(
                        message,
                        textAlign: TextAlign.center,
                        style: _exo(
                          15,
                          FontWeight.w500,
                          color: AppColors.deepGreen.withValues(alpha: 0.78),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _fadeSlide(
                    start: 0.45,
                    end: 0.85,
                    child: _timeline(),
                  ),
                  const SizedBox(height: 24),
                  _fadeSlide(
                    start: 0.55,
                    end: 1,
                    child: FilledButton(
                      onPressed: _refreshing ? null : _refreshStatus,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brandPurple,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 54),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _refreshing
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.refresh_rounded, size: 22),
                                const SizedBox(width: 10),
                                Text(
                                  'Check status',
                                  style: _exo(16, FontWeight.w700),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _fadeSlide(
                    start: 0.62,
                    end: 1,
                    child: DangerSignOutButton(onPressed: _signOut),
                  ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

enum _StepState { done, active, upcoming }

class _TimelineStep {
  const _TimelineStep({
    required this.label,
    required this.icon,
    required this.state,
  });

  final String label;
  final IconData icon;
  final _StepState state;
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.step,
    required this.pulse,
    required this.isLast,
  });

  final _TimelineStep step;
  final Animation<double> pulse;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final isActive = step.state == _StepState.active;
    final isDone = step.state == _StepState.done;

    Color iconBg;
    Color iconFg;
    if (isDone) {
      iconBg = AppColors.kitchenOpen.withValues(alpha: 0.15);
      iconFg = AppColors.kitchenOpen;
    } else if (isActive) {
      iconBg = AppColors.brandPurple.withValues(
        alpha: 0.12 + 0.1 * pulse.value,
      );
      iconFg = AppColors.brandPurple;
    } else {
      iconBg = AppColors.deepGreen.withValues(alpha: 0.06);
      iconFg = AppColors.deepGreen.withValues(alpha: 0.35);
    }

    return Row(
      children: [
        AnimatedBuilder(
          animation: pulse,
          builder: (context, _) {
            final scale = isActive ? 1.0 + 0.06 * pulse.value : 1.0;
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                  border: isActive
                      ? Border.all(
                          color: AppColors.brandPurple.withValues(alpha: 0.35),
                          width: 1.5,
                        )
                      : null,
                ),
                child: Icon(step.icon, size: 20, color: iconFg),
              ),
            );
          },
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            step.label,
            style: GoogleFonts.exo2(
              fontSize: 14,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
              color: isActive
                  ? AppColors.deepGreen
                  : AppColors.deepGreen.withValues(
                      alpha: isDone ? 0.75 : 0.45,
                    ),
            ),
          ),
        ),
        if (isDone)
          Icon(
            Icons.done_all_rounded,
            size: 18,
            color: AppColors.kitchenOpen.withValues(alpha: 0.85),
          ),
        if (isActive)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.brandPurple.withValues(alpha: 0.85),
            ),
          ),
      ],
    );
  }
}

class _OrbitRingPainter extends CustomPainter {
  _OrbitRingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.42;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 3; i++) {
      paint.color = AppColors.brandPurple.withValues(alpha: 0.12 + i * 0.06);
      final start = (progress + i * 0.33) * 2 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - i * 6),
        start,
        math.pi * 0.55,
        false,
        paint,
      );
    }

    paint.color = AppColors.amberGlow.withValues(alpha: 0.55);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      progress * 2 * math.pi,
      math.pi * 0.18,
      false,
      paint..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _OrbitRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _AmbientBlobPainter extends CustomPainter {
  _AmbientBlobPainter({required this.phase});

  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    final blobs = [
      (Alignment(-0.9, -0.85), 0.22, AppColors.brandPurple),
      (Alignment(1.0, -0.5), 0.16, AppColors.terracotta),
      (Alignment(0.2, 1.05), 0.18, AppColors.sage),
    ];

    for (var i = 0; i < blobs.length; i++) {
      final (align, base, color) = blobs[i];
      final offset = align.alongSize(size);
      final drift = math.sin((phase + i * 0.3) * math.pi * 2) * 12;
      paint.color = color.withValues(alpha: base);
      canvas.drawCircle(
        offset + Offset(drift, drift * 0.6),
        size.width * (0.28 + 0.02 * phase),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientBlobPainter oldDelegate) =>
      oldDelegate.phase != phase;
}
