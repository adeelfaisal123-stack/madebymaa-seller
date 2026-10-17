import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seller/data/seller_agreement_content.dart';
import 'package:seller/services/seller_agreement_pdf_service.dart';
import 'package:seller/services/seller_agreement_personalizer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => '.',
    );
  });

  test('buildSellerAgreementPdf produces bytes', () async {
    final context = SellerAgreementContext(
      sellerName: 'Test Seller',
      kitchenName: 'Test Kitchen',
      place: 'Mumbai',
      agreementDate: '13 Jun 2026',
    );
    final segments = buildAgreementSegments(
      sellerAgreementDefaultContent,
      context,
    );

    Uint8List? pdf;
    Object? error;
    try {
      pdf = await buildSellerAgreementPdf(segments: segments);
    } catch (e, st) {
      error = e;
      // ignore: avoid_print
      print('PDF error: $e\n$st');
    }

    expect(error, isNull, reason: '$error');
    expect(pdf, isNotNull);
    expect(pdf!.length, greaterThan(1000));
    expect(String.fromCharCodes(pdf.take(4)), '%PDF');
  });
}
