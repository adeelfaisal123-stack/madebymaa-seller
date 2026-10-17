import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// Drawn signature canvas for document KYC agreement.
class SignaturePad extends StatefulWidget {
  const SignaturePad({
    super.key,
    required this.onChanged,
    this.height = 180,
    this.showInlineClear = true,
  });

  final ValueChanged<bool> onChanged;
  final double height;
  final bool showInlineClear;

  @override
  SignaturePadState createState() => SignaturePadState();
}

class SignaturePadState extends State<SignaturePad> {
  final List<List<Offset?>> _strokes = [];
  List<Offset?> _currentStroke = [];
  Size _canvasSize = Size.zero;

  bool get hasSignature =>
      _strokes.any((stroke) => stroke.whereType<Offset>().length >= 2);

  void clear() {
    setState(() {
      _strokes.clear();
      _currentStroke = [];
    });
    widget.onChanged(false);
  }

  Future<Uint8List?> exportPng() async {
    if (!hasSignature || _canvasSize == Size.zero) {
      return null;
    }

    final width = _canvasSize.width;
    final height = _canvasSize.height;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));

    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height),
      Paint()..color = Colors.white,
    );

    final paint = Paint()
      ..color = AppColors.deepGreen
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in _strokes) {
      final points = stroke.whereType<Offset>().toList();
      if (points.length < 2) {
        continue;
      }
      for (var i = 0; i < points.length - 1; i++) {
        canvas.drawLine(points[i], points[i + 1], paint);
      }
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.ceil(), height.ceil());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  void _notifyChanged() {
    widget.onChanged(hasSignature);
  }

  void _startStroke(Offset point) {
    setState(() {
      _currentStroke = [point];
      _strokes.add(_currentStroke);
    });
  }

  void _extendStroke(Offset point) {
    setState(() => _currentStroke.add(point));
    _notifyChanged();
  }

  void _endStroke() {
    setState(() => _currentStroke.add(null));
    _notifyChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            _canvasSize = Size(constraints.maxWidth, widget.height);

            return ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: widget.height,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                    color: AppColors.brandPurple.withValues(alpha: 0.25),
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Stack(
                  children: [
                    if (!hasSignature)
                      Center(
                        child: Text(
                          'Sign here',
                          style: GoogleFonts.exo2(
                            fontSize: 14,
                            color: AppColors.deepGreen.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                    GestureDetector(
                      onPanStart: (details) =>
                          _startStroke(details.localPosition),
                      onPanUpdate: (details) =>
                          _extendStroke(details.localPosition),
                      onPanEnd: (_) => _endStroke(),
                      child: CustomPaint(
                        size: Size(constraints.maxWidth, widget.height),
                        painter: _SignaturePainter(strokes: _strokes),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        if (widget.showInlineClear) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: hasSignature ? clear : null,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                'Clear signature',
                style: GoogleFonts.exo2(fontWeight: FontWeight.w600),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.brandPurple,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter({required this.strokes});

  final List<List<Offset?>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.deepGreen
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      final points = stroke.whereType<Offset>().toList();
      if (points.length < 2) {
        continue;
      }
      for (var i = 0; i < points.length - 1; i++) {
        canvas.drawLine(points[i], points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) =>
      oldDelegate.strokes != strokes;
}
