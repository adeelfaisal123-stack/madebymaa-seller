import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

/// Lets the embedded Google Maps WebView win gesture arenas (e.g. inside a scroll view).
Set<Factory<OneSequenceGestureRecognizer>> mapWebViewGestureRecognizers() {
  return {
    Factory<OneSequenceGestureRecognizer>(
      () => EagerGestureRecognizer(),
    ),
  };
}
