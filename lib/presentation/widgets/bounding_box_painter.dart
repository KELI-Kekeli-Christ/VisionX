import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/detection_result.dart';

/// CustomPainter haute performance pour le rendu des bounding boxes.
///
/// Stratégie perf :
/// - Isolé dans un [RepaintBoundary] côté parent.
/// - [shouldRepaint] ne retourne true que si la liste change réellement.
/// - Zéro allocation de widgets dans le hot path — tout est canvas.
class BoundingBoxPainter extends CustomPainter {
  BoundingBoxPainter({
    required this.detections,
    required this.threshold,
  });

  final List<DetectionResult> detections;
  final double threshold;

  // Constantes de style
  static const double _cornerLen = 14.0;
  static const double _strokeWidth = 2.0;
  static const double _glowBlur = 12.0;
  static const double _labelPad = 6.0;
  static const double _labelRadius = 6.0;
  static const double _fontSize = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    for (final d in detections) {
      if (d.confidence < threshold) continue;
      _drawDetection(canvas, size, d);
    }
  }

  void _drawDetection(Canvas canvas, Size size, DetectionResult d) {
    final color = AppTheme.bbColor(d.confidence);

    // Boite en coordonnées pixels
    final rect = Rect.fromLTRB(
      d.boundingBox.left * size.width,
      d.boundingBox.top * size.height,
      d.boundingBox.right * size.width,
      d.boundingBox.bottom * size.height,
    );

    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));

    // ── Glow ──────────────────────────────────────────────────
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = color.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, _glowBlur),
    );

    // ── Fond translucide ──────────────────────────────────────
    canvas.drawRRect(
      rrect,
      Paint()..color = color.withValues(alpha: 0.06),
    );

    // ── Coins L-shape ─────────────────────────────────────────
    final cornerPaint = Paint()
      ..color = color
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    _drawCorners(canvas, rect, cornerPaint);

    // ── Label + score ─────────────────────────────────────────
    _drawLabel(canvas, rect, d, color);
  }

  void _drawCorners(Canvas canvas, Rect r, Paint p) {
    final l = _cornerLen;
    // Top-left
    canvas.drawLine(r.topLeft, r.topLeft + Offset(l, 0), p);
    canvas.drawLine(r.topLeft, r.topLeft + Offset(0, l), p);
    // Top-right
    canvas.drawLine(r.topRight, r.topRight + Offset(-l, 0), p);
    canvas.drawLine(r.topRight, r.topRight + Offset(0, l), p);
    // Bottom-left
    canvas.drawLine(r.bottomLeft, r.bottomLeft + Offset(l, 0), p);
    canvas.drawLine(r.bottomLeft, r.bottomLeft + Offset(0, -l), p);
    // Bottom-right
    canvas.drawLine(r.bottomRight, r.bottomRight + Offset(-l, 0), p);
    canvas.drawLine(r.bottomRight, r.bottomRight + Offset(0, -l), p);
  }

  void _drawLabel(
    Canvas canvas,
    Rect boxRect,
    DetectionResult d,
    Color color,
  ) {
    final text = '${d.label}  ${d.confidencePercent}';

    final pb = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        fontSize: _fontSize,
        fontFamily: 'JetBrains Mono',
        fontWeight: FontWeight.w500,
      ),
    )
      ..pushStyle(ui.TextStyle(color: Colors.white, fontSize: _fontSize))
      ..addText(text);

    final para = pb.build()
      ..layout(const ui.ParagraphConstraints(width: 300));

    final textW = para.longestLine + _labelPad * 2;
    final textH = para.height + _labelPad * 2;

    // Position : au-dessus de la box si possible, sinon à l'intérieur
    double labelTop = boxRect.top - textH - 4;
    if (labelTop < 0) labelTop = boxRect.top + 4;
    final labelLeft = boxRect.left;

    final labelRect = Rect.fromLTWH(labelLeft, labelTop, textW, textH);
    final labelRRect =
        RRect.fromRectAndRadius(labelRect, const Radius.circular(_labelRadius));

    // Fond label
    canvas.drawRRect(
      labelRRect,
      Paint()..color = color.withValues(alpha: 0.85),
    );

    // Glow label
    canvas.drawRRect(
      labelRRect,
      Paint()
        ..color = color.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Texte
    canvas.drawParagraph(
      para,
      Offset(labelLeft + _labelPad, labelTop + _labelPad),
    );
  }

  @override
  bool shouldRepaint(BoundingBoxPainter old) =>
      old.detections != detections || old.threshold != threshold;
}
