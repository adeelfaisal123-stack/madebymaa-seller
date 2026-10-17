import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Edge-to-edge system UI — transparent status and navigation bars.
abstract final class AppSystemUi {
  static const overlayLightBackground = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  );

  static const overlayOnDark = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarContrastEnforced: false,
  );

  static Future<void> apply() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(overlayLightBackground);
  }

  static double topInset(BuildContext context, [double extra = 0]) =>
      MediaQuery.viewPaddingOf(context).top + extra;

  static double bottomInset(BuildContext context, [double extra = 0]) =>
      MediaQuery.viewPaddingOf(context).bottom + extra;
}
