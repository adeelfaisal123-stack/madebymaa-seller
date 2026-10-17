import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seller/main.dart';

void main() {
  testWidgets('Shows branded splash', (WidgetTester tester) async {
    await tester.pumpWidget(const SellerApp());
    await tester.pump();

    expect(find.byKey(const ValueKey('splash_headline')), findsOneWidget);
    expect(find.textContaining('Made by Maa'), findsOneWidget);
  });
}
