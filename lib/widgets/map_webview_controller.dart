import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// WebView tuned for embedded Google Maps (touch + drag inside scroll views).
WebViewController createMapWebViewController() {
  late final PlatformWebViewControllerCreationParams params;
  if (WebViewPlatform.instance is AndroidWebViewPlatform) {
    params = AndroidWebViewControllerCreationParams();
  } else {
    params = const PlatformWebViewControllerCreationParams();
  }

  final controller = WebViewController.fromPlatformCreationParams(params);

  if (controller.platform is AndroidWebViewController) {
    final android = controller.platform as AndroidWebViewController;
    android.setMediaPlaybackRequiresUserGesture(false);
  }

  return controller
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setBackgroundColor(const Color(0xFFF5F0E8));
}
