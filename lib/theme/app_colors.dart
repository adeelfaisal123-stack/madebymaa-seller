import 'package:flutter/material.dart';

/// Brand palette: Made by Maa purple + fresh market accents.
abstract final class AppColors {
  /// Logo / primary brand purple.
  static const brandPurple = Color(0xFF6221B3);
  static const brandPurpleDeep = Color(0xFF3D1570);

  static const terracotta = Color(0xFFD4622A);
  static const kitchenOpen = Color(0xFF2E9E5B);
  static const kitchenOpenDeep = Color(0xFF1E6B42);
  static const kitchenOff = Color(0xFFD32F2F);
  static const kitchenOffDeep = Color(0xFF9A1B1B);
  static const deepGreen = Color(0xFF1E4033);
  static const sage = Color(0xFF3D6B55);
  static const cream = Color(0xFFF7F2E9);
  /// Bootstrap 5 warning palette — https://getbootstrap.com/docs/5.3/customize/color/
  static const bootstrapWarning = Color(0xFFFFC107);
  static const bootstrapWarningText = Color(0xFF664D03);
  static const bootstrapWarningBg = Color(0xFFFFF3CD);
  static const bootstrapWarningBorder = Color(0xFFFFECB5);
  static const orderPending = bootstrapWarning;
  /// Same as [bootstrapWarning] (legacy name used across the app).
  static const amberGlow = bootstrapWarning;
}
