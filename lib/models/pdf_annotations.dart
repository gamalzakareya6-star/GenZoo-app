import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/painting.dart';

/// Drawing/typing the user adds on top of a PDF page. Coordinates are
/// normalized (0..1 of the page) so they stay correct at any zoom.
abstract class Annot {
  Map<String, dynamic> toJson();

  static Annot? fromJson(Map<String, dynamic> j) {
    switch (j['t']) {
      case 'stroke':
        return StrokeAnnot(
          highlight: j['h'] as bool? ?? false,
          color: (j['c'] as num).toInt(),
          width: (j['w'] as num).toDouble(),
          points: [
            for (final p in (j['p'] as List<dynamic>))
              Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()),
          ],
        );
      case 'text':
        return TextAnnot(
          text: j['x'] as String? ?? '',
          pos: Offset((j['px'] as num).toDouble(), (j['py'] as num).toDouble()),
          color: (j['c'] as num).toInt(),
          size: (j['s'] as num).toDouble(),
        );
    }
    return null;
  }
}

class StrokeAnnot extends Annot {
  final bool highlight;
  final int color;
  final double width; // fraction of the page width
  final List<Offset> points;

  StrokeAnnot({required this.highlight, required this.color, required this.width, required this.points});

  @override
  Map<String, dynamic> toJson() => {
        't': 'stroke',
        'h': highlight,
        'c': color,
        'w': width,
        'p': [for (final p in points) [double.parse(p.dx.toStringAsFixed(4)), double.parse(p.dy.toStringAsFixed(4))]],
      };
}

class TextAnnot extends Annot {
  final String text;
  final Offset pos;
  final int color;
  final double size; // fraction of the page width

  TextAnnot({required this.text, required this.pos, required this.color, required this.size});

  @override
  Map<String, dynamic> toJson() =>
      {'t': 'text', 'x': text, 'px': pos.dx, 'py': pos.dy, 'c': color, 's': size};
}

class PageAnnotations {
  final List<Annot> items = [];
  bool get isEmpty => items.isEmpty;
}

/// All annotations of one PDF, saved next to the file as `<file>.ann.json`.
class DocAnnotations {
  final Map<int, PageAnnotations> pages = {};

  PageAnnotations page(int n) => pages.putIfAbsent(n, PageAnnotations.new);

  bool get hasAny => pages.values.any((p) => !p.isEmpty);

  static File _file(String pdfPath) => File('$pdfPath.ann.json');

  static Future<DocAnnotations> load(String pdfPath) async {
    final doc = DocAnnotations();
    try {
      final f = _file(pdfPath);
      if (!await f.exists()) return doc;
      final json = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      json.forEach((k, v) {
        final n = int.tryParse(k);
        if (n == null) return;
        final page = doc.page(n);
        for (final a in (v as List<dynamic>)) {
          final annot = Annot.fromJson(Map<String, dynamic>.from(a as Map));
          if (annot != null) page.items.add(annot);
        }
      });
    } catch (_) {}
    return doc;
  }

  Future<void> save(String pdfPath) async {
    final out = <String, dynamic>{};
    pages.forEach((n, p) {
      if (!p.isEmpty) out['$n'] = p.items.map((a) => a.toJson()).toList();
    });
    final f = _file(pdfPath);
    if (out.isEmpty) {
      if (await f.exists()) await f.delete();
    } else {
      await f.writeAsString(jsonEncode(out));
    }
  }
}

/// Paints the annotations of a page on a canvas of [size].
class AnnotationPainter extends CustomPainter {
  final List<Annot> items;
  final StrokeAnnot? current;

  AnnotationPainter(this.items, {this.current});

  @override
  void paint(Canvas canvas, Size size) {
    for (final a in items) {
      _draw(canvas, size, a);
    }
    if (current != null) _draw(canvas, size, current!);
  }

  static void _draw(Canvas canvas, Size size, Annot a) {
    if (a is StrokeAnnot) {
      if (a.points.isEmpty) return;
      final paint = Paint()
        ..color = a.highlight ? Color(a.color).withOpacity(0.35) : Color(a.color)
        ..strokeWidth = a.width * size.width
        ..strokeCap = a.highlight ? StrokeCap.butt : StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final path = Path()..moveTo(a.points.first.dx * size.width, a.points.first.dy * size.height);
      if (a.points.length == 1) {
        path.lineTo(a.points.first.dx * size.width + 0.1, a.points.first.dy * size.height);
      }
      for (final p in a.points.skip(1)) {
        path.lineTo(p.dx * size.width, p.dy * size.height);
      }
      canvas.drawPath(path, paint);
    } else if (a is TextAnnot) {
      final tp = TextPainter(
        text: TextSpan(
          text: a.text,
          style: TextStyle(color: Color(a.color), fontSize: a.size * size.width, height: 1.2),
        ),
        textDirection: TextDirection.rtl,
      )..layout(maxWidth: size.width * 0.9);
      tp.paint(canvas, Offset(a.pos.dx * size.width, a.pos.dy * size.height));
    }
  }

  @override
  bool shouldRepaint(covariant AnnotationPainter old) => true;
}
