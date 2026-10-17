import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Play Store in-app updates (Android) + version label for splash.
abstract final class PlayStoreUpdateService {
  static const androidPackageId = 'com.madebymaa.merchant';

  static final Uri playStoreWebUri = Uri.parse(
    'https://play.google.com/store/apps/details?id=$androidPackageId',
  );

  static final Uri playStoreMarketUri = Uri.parse(
    'market://details?id=$androidPackageId',
  );

  /// e.g. `Version 1.0.0 (1)`
  static Future<String> versionLabel() async {
    final info = await PackageInfo.fromPlatform();
    return 'Version ${info.version} (${info.buildNumber})';
  }

  static Future<PackageInfo> packageInfo() => PackageInfo.fromPlatform();

  /// Returns update info when an Play Store update exists; null otherwise.
  static Future<AppUpdateInfo?> checkForUpdate() async {
    if (kIsWeb || !Platform.isAndroid) {
      return null;
    }

    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        return info;
      }
    } catch (e, st) {
      debugPrint('Play Store update check failed: $e\n$st');
    }

    return null;
  }

  /// Starts an in-app update or opens the Play Store listing.
  static Future<void> startUpdate(AppUpdateInfo info) async {
    if (kIsWeb || !Platform.isAndroid) {
      await openPlayStoreListing();
      return;
    }

    try {
      if (info.immediateUpdateAllowed) {
        final result = await InAppUpdate.performImmediateUpdate();
        if (result == AppUpdateResult.success) {
          return;
        }
      }

      if (info.flexibleUpdateAllowed) {
        await InAppUpdate.startFlexibleUpdate();
        await InAppUpdate.completeFlexibleUpdate();
        return;
      }
    } catch (e, st) {
      debugPrint('In-app update failed: $e\n$st');
    }

    await openPlayStoreListing();
  }

  static Future<bool> openPlayStoreListing() async {
    if (await canLaunchUrl(playStoreMarketUri)) {
      return launchUrl(
        playStoreMarketUri,
        mode: LaunchMode.externalApplication,
      );
    }

    return launchUrl(
      playStoreWebUri,
      mode: LaunchMode.externalApplication,
    );
  }
}
