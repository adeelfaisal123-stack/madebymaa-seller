import 'dart:typed_data';

import 'package:file_save_directory/file_save_directory.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart' show MethodChannel, rootBundle;
import 'package:open_file/open_file.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'seller_agreement_personalizer.dart';

const _pdfDownloadChannel = MethodChannel('com.madebymaa.merchant/pdf_download');

pw.Font? _regularFont;
pw.Font? _boldFont;
pw.MemoryImage? _watermarkImage;

Future<(pw.Font, pw.Font)> _agreementPdfFonts() async {
  if (_regularFont != null && _boldFont != null) {
    return (_regularFont!, _boldFont!);
  }

  final regularData =
      await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
  final boldData = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
  _regularFont = pw.Font.ttf(regularData);
  _boldFont = pw.Font.ttf(boldData);
  return (_regularFont!, _boldFont!);
}

Future<pw.MemoryImage> _agreementWatermark() async {
  if (_watermarkImage != null) {
    return _watermarkImage!;
  }

  final data = await rootBundle.load('assets/images/agreement_watermark.png');
  _watermarkImage = pw.MemoryImage(data.buffer.asUint8List());
  return _watermarkImage!;
}

pw.Widget _buildAgreementBackground(
  pw.Context context,
  pw.MemoryImage watermark,
) {
  return pw.FullPage(
    ignoreMargins: true,
    child: pw.Center(
      child: pw.Opacity(
        opacity: 0.18,
        child: pw.Image(
          watermark,
          width: context.page.pageFormat.width * 0.62,
          fit: pw.BoxFit.contain,
        ),
      ),
    ),
  );
}

Future<Uint8List> buildSellerAgreementPdf({
  required List<AgreementTextSegment> segments,
  Uint8List? signaturePng,
}) async {
  try {
    return await _buildPdf(
      segments: segments,
      signaturePng: signaturePng,
    );
  } catch (_) {
    if (signaturePng != null && signaturePng.isNotEmpty) {
      return _buildPdf(segments: segments, signaturePng: null);
    }
    rethrow;
  }
}

Future<Uint8List> _buildPdf({
  required List<AgreementTextSegment> segments,
  Uint8List? signaturePng,
}) async {
  final (regular, bold) = await _agreementPdfFonts();
  final watermark = await _agreementWatermark();
  final pdf = pw.Document();
  final baseStyle = pw.TextStyle(
    font: regular,
    fontSize: 10.5,
    lineSpacing: 1.45,
  );
  final highlightStyle = pw.TextStyle(
    font: bold,
    fontSize: 10.5,
    lineSpacing: 1.45,
    decoration: pw.TextDecoration.underline,
  );
  final lines = groupAgreementSegmentsByLine(segments);

  pdf.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        buildBackground: (context) =>
            _buildAgreementBackground(context, watermark),
      ),
      build: (context) {
        final widgets = <pw.Widget>[];

        for (final line in lines) {
          final printable = line
              .where((segment) => segment.text.trim().isNotEmpty)
              .toList();

          if (printable.isEmpty) {
            widgets.add(pw.SizedBox(height: 8));
            continue;
          }

          if (printable.length == 1) {
            final segment = printable.first;
            widgets.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Text(
                  segment.text,
                  style: segment.highlight ? highlightStyle : baseStyle,
                ),
              ),
            );
            continue;
          }

          widgets.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.RichText(
                text: pw.TextSpan(
                  children: [
                    for (final segment in printable)
                      pw.TextSpan(
                        text: segment.text,
                        style: segment.highlight ? highlightStyle : baseStyle,
                      ),
                  ],
                ),
              ),
            ),
          );
        }

        if (signaturePng != null && signaturePng.isNotEmpty) {
          widgets.addAll([
            pw.SizedBox(height: 16),
            pw.Text(
              'Seller signature',
              style: baseStyle.copyWith(font: bold),
            ),
            pw.SizedBox(height: 8),
            pw.SizedBox(
              height: 72,
              child: pw.Image(
                pw.MemoryImage(signaturePng),
                fit: pw.BoxFit.contain,
                alignment: pw.Alignment.centerLeft,
              ),
            ),
          ]);
        }

        if (widgets.isEmpty) {
          widgets.add(
            pw.Text('Seller agreement', style: baseStyle),
          );
        }

        return widgets;
      },
    ),
  );

  return Uint8List.fromList(await pdf.save());
}

/// Saves the agreement PDF to Downloads, then opens the saved file.
Future<FileSaveResult> downloadSellerAgreementPdf(Uint8List pdfBytes) async {
  const fileName = 'seller-agreement.pdf';

  if (kIsWeb) {
    await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
    return FileSaveResult(
      success: true,
      message: 'Agreement downloaded.',
    );
  }

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return _downloadAndOpenOnAndroid(pdfBytes, fileName);
  }

  final saveResult = await FileSaveDirectory.instance.saveFile(
    fileName: fileName,
    fileBytes: pdfBytes,
    location: SaveLocation.downloads,
    openAfterSave: false,
  );

  if (!saveResult.success) {
    return saveResult;
  }

  if (saveResult.path != null) {
    final openResult = await OpenFile.open(saveResult.path!);
    if (openResult.type != ResultType.done) {
      return FileSaveResult(
        success: true,
        path: saveResult.path,
        message:
            'Agreement saved to Downloads. Open it from your Files app if it did not open automatically.',
      );
    }
  }

  return FileSaveResult(
    success: true,
    path: saveResult.path,
    message: saveResult.message ?? 'Agreement downloaded and opened.',
  );
}

Future<FileSaveResult> _downloadAndOpenOnAndroid(
  Uint8List pdfBytes,
  String fileName,
) async {
  final response = await _pdfDownloadChannel.invokeMethod<Map<Object?, Object?>>(
    'downloadPdf',
    {
      'fileName': fileName,
      'bytes': pdfBytes,
    },
  );

  if (response?['success'] != true) {
    return FileSaveResult(
      success: false,
      error: 'Could not save agreement PDF to Downloads.',
    );
  }

  final uri = response!['uri'] as String?;
  final savedName = response['fileName'] as String? ?? fileName;
  if (uri == null || uri.isEmpty) {
    return FileSaveResult(
      success: false,
      error: 'Download finished but the saved file could not be found.',
    );
  }

  try {
    await _pdfDownloadChannel.invokeMethod<void>('openPdf', {'uri': uri});
  } catch (_) {
    return FileSaveResult(
      success: true,
      path: uri,
      message:
          '$savedName saved to Downloads. Open it from your Files app if it did not open automatically.',
    );
  }

  return FileSaveResult(
    success: true,
    path: uri,
    message: '$savedName downloaded to Downloads and opened.',
  );
}
