import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../theme/app_colors.dart';
import '../widgets/app_toast.dart';

/// In-app PDF viewer when the system cannot open the agreement URL externally.
class AgreementPdfViewerScreen extends StatefulWidget {
  const AgreementPdfViewerScreen({
    super.key,
    required this.pdfUrl,
  });

  final String pdfUrl;

  @override
  State<AgreementPdfViewerScreen> createState() =>
      _AgreementPdfViewerScreenState();
}

class _AgreementPdfViewerScreenState extends State<AgreementPdfViewerScreen> {
  late final WebViewController _controller;
  var _loading = true;
  var _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _loading = true;
                _loadFailed = false;
              });
            }
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (_) {
            if (mounted) {
              setState(() {
                _loading = false;
                _loadFailed = true;
              });
            }
          },
        ),
      );
    unawaited(_loadPdf());
  }

  Future<void> _loadPdf() async {
    try {
      final response = await http
          .get(Uri.parse(widget.pdfUrl))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final bytes = response.bodyBytes;
      if (bytes.isEmpty) {
        throw Exception('Empty PDF');
      }

      final encoded = base64Encode(bytes);
      await _controller.loadRequest(
        Uri.parse('data:application/pdf;base64,$encoded'),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  Future<void> _openExternally() async {
    final uri = Uri.tryParse(widget.pdfUrl);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        AppToast.danger(context, 'Could not open in browser.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.deepGreen),
        title: Text(
          'Seller agreement',
          style: GoogleFonts.exo2(
            fontWeight: FontWeight.w800,
            color: AppColors.deepGreen,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Open in browser',
            onPressed: _openExternally,
            icon: const Icon(Icons.open_in_browser_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_loadFailed)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Could not load the PDF here.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.exo2(
                        fontWeight: FontWeight.w600,
                        color: AppColors.deepGreen,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _openExternally,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brandPurple,
                      ),
                      child: Text(
                        'Open in browser',
                        style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            WebViewWidget(controller: _controller),
          if (_loading && !_loadFailed)
            const Center(
              child: CircularProgressIndicator(color: AppColors.brandPurple),
            ),
        ],
      ),
    );
  }
}

/// Opens a PDF URL externally when possible, otherwise in-app.
Future<void> openAgreementPdf(BuildContext context, String url) async {
  final trimmed = url.trim();
  if (trimmed.isEmpty) {
    AppToast.warning(context, 'Agreement PDF is not available yet.');
    return;
  }

  final uri = Uri.tryParse(trimmed);
  if (uri == null) {
    AppToast.danger(context, 'Invalid agreement PDF link.');
    return;
  }

  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!context.mounted) return;

  if (launched) return;

  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => AgreementPdfViewerScreen(pdfUrl: trimmed),
    ),
  );
}
