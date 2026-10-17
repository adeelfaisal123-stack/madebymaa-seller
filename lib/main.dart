import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'config/optica2_config.dart';
import 'firebase_bootstrap.dart';
import 'screens/splash_screen.dart';
import 'services/google_maps_config_service.dart';
import 'services/optica2_api.dart';
import 'services/seller_push_service.dart';
import 'theme/app_colors.dart';
import 'utils/app_system_ui.dart';

final _navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSystemUi.apply();
  try {
    await ensureFirebaseInitialized();
  } catch (e, st) {
    debugPrint('Firebase init in main() failed: $e\n$st');
  }
  await Optica2Config.initialize();
  SellerPushService.bindNavigator(_navigatorKey);
  try {
    await SellerPushService.ensureReady();
  } catch (e, st) {
    debugPrint('Push notifications init skipped: $e\n$st');
  }
  runApp(const SellerApp());
  unawaited(_preloadMapsConfig());
}

Future<void> _preloadMapsConfig() async {
  try {
    await GoogleMapsConfigService.ensureLoaded(api: Optica2Api());
  } catch (e, st) {
    debugPrint('Maps config preload skipped: $e\n$st');
  }
}

class SellerApp extends StatelessWidget {
  const SellerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.brandPurple,
      brightness: Brightness.light,
      primary: AppColors.brandPurple,
      secondary: AppColors.terracotta,
      surface: AppColors.cream,
      onPrimary: Colors.white,
    );

    final baseTheme = ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
    );

    final exo = GoogleFonts.exo2TextTheme(baseTheme.textTheme).apply(
      bodyColor: AppColors.deepGreen,
      displayColor: AppColors.deepGreen,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppSystemUi.overlayLightBackground,
      child: MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Seller',
      debugShowCheckedModeBanner: false,
      theme: baseTheme.copyWith(
        scaffoldBackgroundColor: AppColors.cream,
        textTheme: exo,
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.cream,
          foregroundColor: AppColors.deepGreen,
          elevation: 0,
          centerTitle: false,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: GoogleFonts.exo2(
            textStyle: baseTheme.textTheme.titleLarge,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.24,
            color: AppColors.deepGreen,
          ),
        ),
      ),
      home: const SplashScreen(),
      ),
    );
  }
}
