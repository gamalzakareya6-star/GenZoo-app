import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/pdf_annotations.dart';

/// Names and default sizes of the pens offered in the editor tray.
class PenSpec {
  final PenKind kind;
  final String label;
  final double defaultWidth; // fraction of the page width
  const PenSpec(this.kind, this.label, this.defaultWidth);
}

const penSpecs = <PenSpec>[
  PenSpec(PenKind.ballpoint, 'جاف', 0.003),
  PenSpec(PenKind.fountain, 'حبر', 0.004),
  PenSpec(PenKind.marker, 'ماركر', 0.004),
  PenSpec(PenKind.pencil, 'رصاص', 0.003),
  PenSpec(PenKind.brush, 'فرشاة', 0.005),
  PenSpec(PenKind.highlighter, 'تظليل', 0.006),
  PenSpec(PenKind.neon, 'نيون', 0.003),
  PenSpec(PenKind.dashed, 'منقّط', 0.003),
];

const defaultPenColors = <PenKind, int>{
  PenKind.ballpoint: 0xFF2563EB,
  PenKind.fountain: 0xFF111827,
  PenKind.marker: 0xFFDC2626,
  PenKind.pencil: 0xFF374151,
  PenKind.brush: 0xFF7C3AED,
  PenKind.highlighter: 0xFFFDE047,
  PenKind.neon: 0xFF22D3EE,
  PenKind.dashed: 0xFFEA580C,
};

class ShapeSpec {
  final ShapeKind kind;
  final String label;
  final IconData icon;
  const ShapeSpec(this.kind, this.label, this.icon);
}

const shapeSpecs = <ShapeSpec>[
  ShapeSpec(ShapeKind.line, 'خط', Icons.horizontal_rule_rounded),
  ShapeSpec(ShapeKind.arrow, 'سهم', Icons.north_east_rounded),
  ShapeSpec(ShapeKind.rect, 'مربع', Icons.crop_square_rounded),
  ShapeSpec(ShapeKind.ellipse, 'دائرة', Icons.circle_outlined),
  ShapeSpec(ShapeKind.box, 'تظليل مربع', Icons.highlight_alt_rounded),
];

/// A drawn pen (body + tip in the current colour). It pops up when selected.
class PenIllustration extends StatelessWidget {
  final PenKind kind;
  final Color color;
  final bool selected;
  const PenIllustration({super.key, required this.kind, required this.color, required this.selected});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(30, 64),
      painter: _PenPainter(kind, color, selected),
    );
  }
}

class _PenPainter extends CustomPainter {
  final PenKind kind;
  final Color color;
  final bool selected;
  _PenPainter(this.kind, this.color, this.selected);

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.2, h * 0.36, w * 0.6, h * 0.64),
      const Radius.circular(6),
    );

    if (selected && kind == PenKind.neon) {
      canvas.drawCircle(
        Offset(w / 2, h * 0.2),
        w * 0.55,
        Paint()
          ..color = color.withOpacity(0.7)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    // Body.
    final bodyColors = switch (kind) {
      PenKind.neon => [const Color(0xFF1F2937), const Color(0xFF0B1220)],
      PenKind.pencil => [const Color(0xFFFCD34D), const Color(0xFFF59E0B)],
      PenKind.highlighter => [color.withOpacity(0.9), color.withOpacity(0.55)],
      PenKind.fountain => [const Color(0xFF1E293B), const Color(0xFF020617)],
      _ => [const Color(0xFFF8FAFC), const Color(0xFFCBD5E1)],
    };
    canvas.drawRRect(
      body,
      Paint()
        ..shader = LinearGradient(colors: bodyColors, begin: Alignment.centerLeft, end: Alignment.centerRight)
            .createShader(body.outerRect),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.black.withOpacity(0.18),
    );

    // Colour band, tells the colour at a glance.
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.2, h * 0.5, w * 0.6, h * 0.09), const Radius.circular(2)),
      Paint()..color = color,
    );
    if (kind == PenKind.dashed) {
      final p = Paint()..color = color..strokeWidth = 1.6;
      for (var i = 0; i < 4; i++) {
        canvas.drawLine(Offset(w * 0.3, h * (0.68 + i * 0.07)), Offset(w * 0.7, h * (0.68 + i * 0.07)), p..strokeCap = StrokeCap.round);
      }
    }

    // Tip.
    final tip = Path();
    final tipPaint = Paint()..color = color;
    switch (kind) {
      case PenKind.ballpoint:
      case PenKind.dashed:
        tip
          ..moveTo(w * 0.3, h * 0.36)
          ..lineTo(w * 0.7, h * 0.36)
          ..lineTo(w * 0.5, h * 0.12)
          ..close();
        tipPaint.color = const Color(0xFF94A3B8);
      case PenKind.fountain:
        tip
          ..moveTo(w * 0.28, h * 0.36)
          ..lineTo(w * 0.72, h * 0.36)
          ..lineTo(w * 0.6, h * 0.16)
          ..lineTo(w * 0.5, h * 0.06)
          ..lineTo(w * 0.4, h * 0.16)
          ..close();
        tipPaint.color = const Color(0xFFD4AF37);
      case PenKind.marker:
        tip.addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.3, h * 0.12, w * 0.4, h * 0.26), const Radius.circular(6)));
      case PenKind.pencil:
        tip
          ..moveTo(w * 0.2, h * 0.36)
          ..lineTo(w * 0.8, h * 0.36)
          ..lineTo(w * 0.5, h * 0.08)
          ..close();
        tipPaint.color = const Color(0xFFE7C9A0);
      case PenKind.brush:
        tip
          ..moveTo(w * 0.3, h * 0.36)
          ..quadraticBezierTo(w * 0.2, h * 0.2, w * 0.5, h * 0.04)
          ..quadraticBezierTo(w * 0.8, h * 0.2, w * 0.7, h * 0.36)
          ..close();
      case PenKind.highlighter:
        tip
          ..moveTo(w * 0.22, h * 0.36)
          ..lineTo(w * 0.78, h * 0.36)
          ..lineTo(w * 0.78, h * 0.2)
          ..lineTo(w * 0.34, h * 0.08)
          ..close();
      case PenKind.neon:
        tip
          ..moveTo(w * 0.32, h * 0.36)
          ..lineTo(w * 0.68, h * 0.36)
          ..lineTo(w * 0.5, h * 0.12)
          ..close();
    }
    canvas.drawPath(tip, tipPaint);
    canvas.drawPath(
      tip,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.black.withOpacity(0.2),
    );
    if (kind == PenKind.ballpoint || kind == PenKind.dashed || kind == PenKind.neon) {
      canvas.drawCircle(Offset(w * 0.5, h * 0.12), 2.4, Paint()..color = color);
    }
    if (kind == PenKind.pencil) {
      final lead = Path()
        ..moveTo(w * 0.4, h * 0.19)
        ..lineTo(w * 0.6, h * 0.19)
        ..lineTo(w * 0.5, h * 0.08)
        ..close();
      canvas.drawPath(lead, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _PenPainter old) =>
      old.kind != kind || old.color != color || old.selected != selected;
}

/// A small sample of what the chosen pen looks like with its colour, width
/// and opacity.
class StrokePreview extends StatelessWidget {
  final PenKind pen;
  final int color;
  final double width; // fraction of the page width
  final double opacity;
  const StrokePreview({super.key, required this.pen, required this.color, required this.width, required this.opacity});

  @override
  Widget build(BuildContext context) {
    const size = Size(104, 38);
    final pts = [
      for (var i = 0; i <= 28; i++)
        Offset(0.08 + 0.84 * i / 28, 0.5 + 0.28 * math.sin(i / 28 * math.pi * 2)),
    ];
    // The page is roughly 360 px wide on screen; scale the width to the preview.
    final annot = StrokeAnnot(pen: pen, color: color, width: width * 360 / size.width, opacity: opacity, points: pts);
    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
      ),
      child: CustomPaint(painter: AnnotationPainter([annot])),
    );
  }
}

/// Colours used most recently (shared by all tools).
final List<int> recentPdfColors = [];

const _palette = <int>[
  0xFF000000, 0xFF374151, 0xFF6B7280, 0xFF9CA3AF, 0xFFD1D5DB, 0xFFF3F4F6, 0xFFFFFFFF, 0xFF7F1D1D,
  0xFFDC2626, 0xFFEF4444, 0xFFF87171, 0xFFFCA5A5, 0xFF9A3412, 0xFFEA580C, 0xFFF97316, 0xFFFB923C,
  0xFFFDBA74, 0xFFA16207, 0xFFCA8A04, 0xFFFACC15, 0xFFFDE047, 0xFFFEF08A, 0xFF14532D, 0xFF15803D,
  0xFF16A34A, 0xFF4ADE80, 0xFFBBF7D0, 0xFF115E59, 0xFF0D9488, 0xFF2DD4BF, 0xFF0E7490, 0xFF06B6D4,
  0xFF22D3EE, 0xFF1E3A8A, 0xFF2563EB, 0xFF3B82F6, 0xFF60A5FA, 0xFF93C5FD, 0xFF4C1D95, 0xFF7C3AED,
  0xFF8B5CF6, 0xFFA78BFA, 0xFF9D174D, 0xFFDB2777, 0xFFEC4899, 0xFFF472B6, 0xFFF9A8D4, 0xFF78350F,
];

/// Bottom sheet with a colour grid and HSV sliders. Returns the chosen ARGB.
Future<int?> showPdfColorSheet(BuildContext context, int initial) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ColorSheet(initial: initial),
  );
}

class _ColorSheet extends StatefulWidget {
  final int initial;
  const _ColorSheet({required this.initial});

  @override
  State<_ColorSheet> createState() => _ColorSheetState();
}

class _ColorSheetState extends State<_ColorSheet> {
  late HSVColor _hsv = HSVColor.fromColor(Color(widget.initial));

  @override
  Widget build(BuildContext context) {
    final current = _hsv.toColor();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: current,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black26),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text('اختر اللون', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                FilledButton(
                  onPressed: () => Navigator.pop(context, current.value),
                  child: const Text('تم'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 8,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                for (final c in _palette)
                  GestureDetector(
                    onTap: () => setState(() => _hsv = HSVColor.fromColor(Color(c))),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: current.value == c ? AppColors.primary : Colors.black12,
                          width: current.value == c ? 3 : 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _slider('درجة اللون', _hsv.hue, 0, 360, (v) => setState(() => _hsv = _hsv.withHue(v))),
            _slider('التشبّع', _hsv.saturation, 0, 1, (v) => setState(() => _hsv = _hsv.withSaturation(v))),
            _slider('السطوع', _hsv.value, 0, 1, (v) => setState(() => _hsv = _hsv.withValue(v))),
          ],
        ),
      ),
    );
  }

  Widget _slider(String label, double v, double min, double max, ValueChanged<double> on) {
    return Row(
      children: [
        SizedBox(width: 70, child: Text(label, style: const TextStyle(fontSize: 12))),
        Expanded(child: Slider(value: v.clamp(min, max), min: min, max: max, onChanged: on)),
      ],
    );
  }
}
