import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:in_app_update/in_app_update.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_bootstrap.dart';
import '../onboarding_prefs.dart';
import '../seller_auth_prefs.dart';
import '../models/otp_config.dart';
import '../services/optica2_api.dart';
import '../services/play_store_update_service.dart';
import '../services/seller_auth_navigation.dart';
import '../theme/app_colors.dart';
import '../utils/app_system_ui.dart';
import '../widgets/play_store_update_dialog.dart';
import 'intro_onboarding_screen.dart';
import 'phone_auth_screen.dart';

/// Splash: brand purple field, white logo, animated tagline.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _reveal;
  late final AnimationController _shimmer;
  late final AnimationController _float;
  Timer? _navTimer;

  String _versionLabel = '';
  AppUpdateInfo? _playStoreUpdate;
  bool _updateCheckDone = false;

  static const _assetLogo = AssetImage('assets/images/made_by_maa_logo.png');

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
    _float = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat(reverse: true);

    unawaited(_loadVersionLabel());
    unawaited(_checkPlayStoreUpdate());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(_assetLogo, context);
      _reveal.forward();
      _navTimer = Timer(const Duration(milliseconds: 3800), _goHome);
    });
  }

  Future<void> _loadVersionLabel() async {
    try {
      final label = await PlayStoreUpdateService.versionLabel();
      if (!mounted) return;
      setState(() => _versionLabel = label);
    } catch (e, st) {
      debugPrint('Version label failed: $e\n$st');
    }
  }

  Future<void> _checkPlayStoreUpdate() async {
    try {
      _playStoreUpdate = await PlayStoreUpdateService.checkForUpdate();
    } catch (e, st) {
      debugPrint('Play Store update check failed: $e\n$st');
    } finally {
      _updateCheckDone = true;
    }
  }

  Future<void> _promptPlayStoreUpdateIfNeeded() async {
    if (!_updateCheckDone) {
      await _checkPlayStoreUpdate();
    }

    final update = _playStoreUpdate;
    if (!mounted || update == null) return;

    final shouldUpdate = await showPlayStoreUpdateDialog(
      context,
      updateInfo: update,
    );
    if (shouldUpdate == true && mounted) {
      await PlayStoreUpdateService.startUpdate(update);
    }
  }

  Future<void> _goHome() async {
    if (!mounted) return;

    await _promptPlayStoreUpdateIfNeeded();
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final onboardingDone =
        prefs.getBool(OnboardingPrefs.completedKey) ?? false;

    if (!onboardingDone) {
      _replace(const IntroOnboardingScreen());
      return;
    }

    try {
      final next = await _resolveNextScreen().timeout(
        const Duration(seconds: 10),
        onTimeout: () => const PhoneAuthScreen(),
      );
      if (!mounted) return;
      _replace(next);
    } catch (e, st) {
      debugPrint('Splash navigation failed: $e\n$st');
      if (!mounted) return;
      _replace(const PhoneAuthScreen());
    }
  }

  Future<Widget> _resolveNextScreen() async {
    final api = Optica2Api(recoverHostOnFailure: false);
    try {
      OtpConfig? otpConfig;
      try {
        otpConfig = await api.fetchOtpConfig();
      } catch (_) {
        otpConfig = null;
      }

      final useMsg91 = otpConfig?.isMsg91 ?? false;
      User? user;
      if (!useMsg91) {
        try {
          await ensureFirebaseInitialized();
          user = FirebaseAuth.instance.currentUser;
        } catch (_) {
          user = null;
        }
      }

      final otpDone = await SellerAuthPrefs.isOtpVerified();
      final savedPhone = await SellerAuthPrefs.phoneE164();
      final phone = user?.phoneNumber ?? savedPhone;

      if (otpDone && phone != null && phone.isNotEmpty) {
        final kycOrHome = (!useMsg91 && user != null)
            ? await SellerAuthNavigation.destinationForSignedInUser(api)
            : await SellerAuthNavigation.destinationForSavedPhone(api, phone);
        return kycOrHome ?? const PhoneAuthScreen();
      }

      return const PhoneAuthScreen();
    } finally {
      api.close();
    }
  }

  void _replace(Widget next) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 650),
        pageBuilder: (_, _, _) => next,
        transitionsBuilder: (_, animation, secondary, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutQuad,
            ),
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _reveal.dispose();
    _shimmer.dispose();
    _float.dispose();
    super.dispose();
  }

  TextStyle _exo(
    double size,
    FontWeight w, {
    Color? color,
    double height = 1,
    double letterSpacing = 0,
  }) {
    return GoogleFonts.exo2(
      fontSize: size,
      fontWeight: w,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.viewPaddingOf(context).top;
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    final logoWidth =
        math.min(MediaQuery.sizeOf(context).width * 0.78, 320.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppSystemUi.overlayOnDark,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            _SplashBackground(reveal: _reveal, float: _float),
            Padding(
              padding: EdgeInsets.fromLTRB(28, top + 20, 28, bottom + 28),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 12),
                          _LogoCard(
                            reveal: _reveal,
                            float: _float,
                            logoWidth: logoWidth,
                          ),
                          const SizedBox(height: 40),
                          _BrandTitle(reveal: _reveal, shimmer: _shimmer, exo: _exo),
                          const SizedBox(height: 22),
                          _TaglinePills(reveal: _reveal, exo: _exo),
                          const SizedBox(height: 48),
                          _LoadingFooter(reveal: _reveal, exo: _exo),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_versionLabel.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: bottom + 12,
                child: Center(
                  child: Text(
                    _versionLabel,
                    style: _exo(
                      11,
                      FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.52),
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SplashBackground extends StatelessWidget {
  const _SplashBackground({
    required this.reveal,
    required this.float,
  });

  final Animation<double> reveal;
  final Animation<double> float;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([reveal, float]),
      builder: (context, _) {
        final p = Curves.easeOut.transform(reveal.value.clamp(0, 1));
        final drift = Curves.easeInOut.transform(float.value);

        return Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF7B3FD4),
                    AppColors.brandPurple,
                    AppColors.brandPurpleDeep,
                    Color(0xFF2A0F52),
                  ],
                  stops: [0.0, 0.35, 0.72, 1.0],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.1 - 0.15 * drift, -0.72),
                  radius: 0.95,
                  colors: [
                    AppColors.amberGlow.withValues(alpha: 0.28 * p),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.85 + 0.1 * drift, 0.55),
                  radius: 0.7,
                  colors: [
                    AppColors.kitchenOpen.withValues(alpha: 0.12 * p),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            CustomPaint(
              painter: _SplashOrbsPainter(
                progress: p,
                drift: drift,
              ),
              size: Size.infinite,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.06),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.32),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SplashOrbsPainter extends CustomPainter {
  _SplashOrbsPainter({required this.progress, required this.drift});

  final double progress;
  final double drift;

  @override
  void paint(Canvas canvas, Size size) {
    void orb(Offset center, double radius, Color color) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }

    final w = size.width;
    final h = size.height;

    orb(
      Offset(w * (0.12 + 0.04 * drift), h * (0.18 - 0.03 * drift)),
      w * 0.22 * progress,
      AppColors.amberGlow.withValues(alpha: 0.2),
    );
    orb(
      Offset(w * (0.88 - 0.05 * drift), h * (0.28 + 0.04 * drift)),
      w * 0.18 * progress,
      Colors.white.withValues(alpha: 0.08),
    );
    orb(
      Offset(w * 0.5, h * (0.78 + 0.02 * drift)),
      w * 0.35 * progress,
      AppColors.brandPurple.withValues(alpha: 0.15),
    );
  }

  @override
  bool shouldRepaint(covariant _SplashOrbsPainter old) =>
      old.progress != progress || old.drift != drift;
}

class _LogoCard extends StatelessWidget {
  const _LogoCard({
    required this.reveal,
    required this.float,
    required this.logoWidth,
  });

  final Animation<double> reveal;
  final Animation<double> float;
  final double logoWidth;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([reveal, float]),
      builder: (context, _) {
        final enter = Curves.elasticOut
            .transform((reveal.value / 0.38).clamp(0.0, 1.0));
        final bob = 5 * math.sin(float.value * math.pi * 2);

        return Transform.translate(
          offset: Offset(0, bob),
          child: Transform.scale(
            scale: enter.clamp(0.0, 1.12),
            child: Opacity(
              opacity: (reveal.value / 0.2).clamp(0.0, 1.0),
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
                child: Image.asset(
                  'assets/images/made_by_maa_logo.png',
                  width: logoWidth,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BrandTitle extends StatelessWidget {
  const _BrandTitle({
    required this.reveal,
    required this.shimmer,
    required this.exo,
  });

  final Animation<double> reveal;
  final Animation<double> shimmer;
  final TextStyle Function(
    double size,
    FontWeight w, {
    Color? color,
    double height,
    double letterSpacing,
  }) exo;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([reveal, shimmer]),
      builder: (context, _) {
        final t2 = ((reveal.value - 0.34) / 0.22).clamp(0.0, 1.0);
        final c2 = Curves.easeOutCubic.transform(t2);

        Widget fadeSlide(double curved, Widget child) {
          return Opacity(
            opacity: curved,
            child: Transform.translate(
              offset: Offset(0, 18 * (1 - curved)),
              child: child,
            ),
          );
        }

        final headline = ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            final start = -1.0 + 2.2 * shimmer.value;
            return LinearGradient(
              colors: [
                Colors.white,
                AppColors.amberGlow,
                Colors.white,
              ],
              stops: const [0.2, 0.5, 0.85],
              begin: Alignment(start, -0.5),
              end: Alignment(start + 1.2, 0.5),
            ).createShader(bounds);
          },
          child: Text(
            'Seller',
            style: exo(
              48,
              FontWeight.w800,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
        );

        return fadeSlide(c2, headline);
      },
    );
  }
}

class _TaglinePills extends StatelessWidget {
  const _TaglinePills({required this.reveal, required this.exo});

  final Animation<double> reveal;
  final TextStyle Function(
    double size,
    FontWeight w, {
    Color? color,
    double height,
    double letterSpacing,
  }) exo;

  static const _items = [
    (Icons.restaurant_menu_rounded, 'Cook'),
    (Icons.storefront_rounded, 'Sell'),
    (Icons.payments_rounded, 'Earn'),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: reveal,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _items.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              _pill(i, _items[i].$1, _items[i].$2),
            ],
          ],
        );
      },
    );
  }

  Widget _pill(int index, IconData icon, String label) {
    final start = 0.52 + index * 0.1;
    final raw = ((reveal.value - start) / 0.14).clamp(0.0, 1.0);
    final curved = Curves.easeOutBack.transform(raw);
    final opacity = curved.clamp(0.0, 1.0);
    final scale = (0.85 + 0.15 * curved.clamp(0.0, 1.0));

    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.22),
                Colors.white.withValues(alpha: 0.08),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
            boxShadow: [
              BoxShadow(
                blurRadius: 16,
                offset: const Offset(0, 6),
                color: Colors.black.withValues(alpha: 0.18),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppColors.amberGlow),
              const SizedBox(width: 6),
              Text(
                label,
                style: exo(
                  15,
                  FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingFooter extends StatelessWidget {
  const _LoadingFooter({required this.reveal, required this.exo});

  final Animation<double> reveal;
  final TextStyle Function(
    double size,
    FontWeight w, {
    Color? color,
    double height,
    double letterSpacing,
  }) exo;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: reveal,
      builder: (context, _) {
        final visible = reveal.value > 0.7;
        return Opacity(
          opacity: visible ? 1 : 0,
          child: Column(
            children: [
              Text(
                'Preparing your stall…',
                style: exo(
                  12,
                  FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.65),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: 140,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.amberGlow.withValues(alpha: 0.95),
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
