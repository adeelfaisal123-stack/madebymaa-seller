import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../onboarding_prefs.dart';
import '../theme/app_colors.dart';
import '../utils/app_system_ui.dart';
import 'phone_auth_screen.dart';

class IntroOnboardingScreen extends StatefulWidget {
  const IntroOnboardingScreen({super.key});

  @override
  State<IntroOnboardingScreen> createState() => _IntroOnboardingScreenState();
}

class _IntroOnboardingScreenState extends State<IntroOnboardingScreen> {
  final PageController _pageController = PageController();
  double _page = 0;

  static const _slides = <_IntroSlide>[
    _IntroSlide(
      image: 'assets/images/intro_1.png',
      title: 'Showcase your kitchen',
      body:
          'Photograph fresh produce and specials — buyers eat with their eyes first.',
    ),
    _IntroSlide(
      image: 'assets/images/intro_2.png',
      title: 'Serve every order',
      body:
          'Stay on top of pickups and deliveries with a flow built for busy market days.',
    ),
    _IntroSlide(
      image: 'assets/images/intro_3.png',
      title: 'Grow with confidence',
      body:
          'Track what sells, adjust pricing, and keep your kitchen humming.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final s in _slides) {
        precacheImage(AssetImage(s.image), context);
      }
    });
  }

  void _onScroll() {
    final p = _pageController.page;
    if (p != null && (p - _page).abs() > 0.001) {
      setState(() => _page = p);
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_onScroll);
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(OnboardingPrefs.completedKey, true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, _, _) => const PhoneAuthScreen(),
        transitionsBuilder: (_, animation, secondary, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final last = _page.round() >= _slides.length - 1;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: AppSystemUi.topInset(context)),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _complete,
                child: Text(
                  'Skip',
                  style: GoogleFonts.exo2(
                    fontWeight: FontWeight.w600,
                    color: scheme.primary.withValues(alpha: 0.75),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                itemBuilder: (context, index) {
                  return _IntroSlideView(
                    slide: _slides[index],
                    pageOffset: _page - index,
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) {
                final active = (_page - i).abs() < 0.5;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  width: active ? 28 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: active
                        ? AppColors.brandPurple
                        : AppColors.brandPurple.withValues(alpha: 0.22),
                  ),
                );
              }),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                20,
                24,
                AppSystemUi.bottomInset(context, 28),
              ),
              child: FilledButton(
                onPressed: last
                    ? _complete
                    : () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 420),
                          curve: Curves.easeOutCubic,
                        );
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  last ? 'Finish' : 'Next',
                  style: GoogleFonts.exo2(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
          ],
        ),
    );
  }
}

class _IntroSlide {
  const _IntroSlide({
    required this.image,
    required this.title,
    required this.body,
  });

  final String image;
  final String title;
  final String body;
}

class _IntroSlideView extends StatelessWidget {
  const _IntroSlideView({
    required this.slide,
    required this.pageOffset,
  });

  final _IntroSlide slide;
  final double pageOffset;

  @override
  Widget build(BuildContext context) {
    final o = pageOffset.abs().clamp(0.0, 1.0);
    final opacity = (1 - o * 0.65).clamp(0.35, 1.0);
    final translate = pageOffset * 36;
    final scale = 1 - o * 0.06;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Expanded(
            flex: 5,
            child: Transform.translate(
              offset: Offset(translate, 0),
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 32,
                          offset: const Offset(0, 18),
                          color: AppColors.brandPurple.withValues(alpha: 0.18),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Image.asset(
                        slide.image,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Transform.translate(
            offset: Offset(0, 12 * o),
            child: Opacity(
              opacity: (1 - o * 1.1).clamp(0.0, 1.0),
              child: Column(
                children: [
                  Text(
                    slide.title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.exo2(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      color: AppColors.deepGreen,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    slide.body,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.exo2(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                      color: AppColors.deepGreen.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(flex: 1),
        ],
      ),
    );
  }
}
