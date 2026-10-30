import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/rendering.dart';

/// Everything the user adds on top of a PDF page. Coordinates are normalized
/// (0..1 of the page) and widths are fractions of the page width, so the
/// drawing stays correct at any zoom and when the page is exported.

enum PenKind { ballpoint, fountain, marker, pencil, brush, highlighter, neon, dashed }

enum ShapeKind { line, arrow, rect, ellipse, box }

abstract class Annot {
  Map<String, dynamic> toJson();

  /// Moves the item by [d] (normalized units).
  void shift(Offset d);

  /// Bounding box in pixels for a page of [size].
  Rect bounds(Size size);

  /// Whether a touch at [p] (pixels) hits the item.
  bool hit(Offset p, Size size, double tol);

  Annot clone() => Annot.fromJson(Map<String, dynamic>.from(jsonDecode(jsonEncode(toJson())) as Map))!;

  static Annot? fromJson(Map<String, dynamic> j) {
    switch (j['t']) {
      case 'stroke':
        final kindName = j['k'] as String? ?? ((j['h'] as bool? ?? false) ? 'highlighter' : 'ballpoint');
        final prs = j['pr'] as List<dynamic>?;
        return StrokeAnnot(
          pen: PenKind.values.firstWhere((k) => k.name == kindName, orElse: () => PenKind.ballpoint),
          color: (j['c'] as num).toInt(),
          width: (j['w'] as num).toDouble(),
          opacity: (j['o'] as num?)?.toDouble() ?? 1.0,
          points: [
            for (final p in (j['p'] as List<dynamic>)) Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()),
          ],
          pressures: prs == null ? null : [for (final v in prs) (v as num).toDouble()],
        );
      case 'shape':
        return ShapeAnnot(
          kind: ShapeKind.values.firstWhere((k) => k.name == (j['k'] as String? ?? 'line'), orElse: () => ShapeKind.line),
          a: Offset((j['ax'] as num).toDouble(), (j['ay'] as num).toDouble()),
          b: Offset((j['bx'] as num).toDouble(), (j['by'] as num).toDouble()),
          color: (j['c'] as num).toInt(),
          width: (j['w'] as num).toDouble(),
          opacity: (j['o'] as num?)?.toDouble() ?? 1.0,
          fill: j['f'] as bool? ?? false,
        );
      case 'text':
        return TextAnnot(
          text: j['x'] as String? ?? '',
          pos: Offset((j['px'] as num).toDouble(), (j['py'] as num).toDouble()),
          color: (j['c'] as num).toInt(),
          size: (j['s'] as num).toDouble(),
          bold: j['b'] as bool? ?? false,
          background: j['bg'] as bool? ?? false,
        );
    }
    return null;
  }
}

class StrokeAnnot extends Annot {
  final PenKind pen;
  final int color;
  final double width; // fraction of the page width
  final double opacity;
  final List<Offset> points;
  final List<double>? pressures;

  StrokeAnnot({
    required this.pen,
    required this.color,
    required this.width,
    this.opacity = 1.0,
    required this.points,
    this.pressures,
  });

  @override
  Map<String, dynamic> toJson() => {
        't': 'stroke',
        'k': pen.name,
        'c': color,
        'w': width,
        'o': opacity,
        'p': [for (final p in points) [double.parse(p.dx.toStringAsFixed(4)), double.parse(p.dy.toStringAsFixed(4))]],
        if (pressures != null) 'pr': [for (final v in pressures!) double.parse(v.toStringAsFixed(3))],
      };

  @override
  void shift(Offset d) {
    for (var i = 0; i < points.length; i++) {
      points[i] = points[i] + d;
    }
  }

  @override
  Rect bounds(Size size) {
    if (points.isEmpty) return Rect.zero;
    var minX = points.first.dx, maxX = minX, minY = points.first.dy, maxY = minY;
    for (final p in points) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }
    return Rect.fromLTRB(minX * size.width, minY * size.height, maxX * size.width, maxY * size.height)
        .inflate(width * size.width * 0.8 + 2);
  }

  @override
  bool hit(Offset p, Size size, double tol) {
    final r = width * size.width * (pen == PenKind.highlighter ? 2.5 : 0.8);
    Offset px(Offset n) => Offset(n.dx * size.width, n.dy * size.height);
    if (points.length == 1) return (px(points.first) - p).distance <= tol + r;
    for (var i = 1; i < points.length; i++) {
      if (_distToSegment(p, px(points[i - 1]), px(points[i])) <= tol + r) return true;
    }
    return false;
  }
}

class ShapeAnnot extends Annot {
  final ShapeKind kind;
  Offset a;
  Offset b;
  final int color;
  final double width;
  final double opacity;
  final bool fill;

  ShapeAnnot({
    required this.kind,
    required this.a,
    required this.b,
    required this.color,
    required this.width,
    this.opacity = 1.0,
    this.fill = false,
  });

  @override
  Map<String, dynamic> toJson() => {
        't': 'shape',
        'k': kind.name,
        'ax': a.dx,
        'ay': a.dy,
        'bx': b.dx,
        'by': b.dy,
        'c': color,
        'w': width,
        'o': opacity,
        'f': fill,
      };

  @override
  void shift(Offset d) {
    a = a + d;
    b = b + d;
  }

  @override
  Rect bounds(Size size) => Rect.fromPoints(
        Offset(a.dx * size.width, a.dy * size.height),
        Offset(b.dx * size.width, b.dy * size.height),
      ).inflate(width * size.width + 4);

  @override
  bool hit(Offset p, Size size, double tol) {
    final pa = Offset(a.dx * size.width, a.dy * size.height);
    final pb = Offset(b.dx * size.width, b.dy * size.height);
    switch (kind) {
      case ShapeKind.line:
      case ShapeKind.arrow:
        return _distToSegment(p, pa, pb) <= tol + width * size.width;
      case ShapeKind.box:
        return Rect.fromPoints(pa, pb).inflate(tol).contains(p);
      case ShapeKind.rect:
      case ShapeKind.ellipse:
        final r = Rect.fromPoints(pa, pb);
        if (fill) return r.inflate(tol).contains(p);
        // Hollow shapes are picked by their outline only.
        return r.inflate(tol + width * size.width).contains(p) && !r.deflate(tol + width * size.width).contains(p);
    }
  }
}

class TextAnnot extends Annot {
  String text;
  Offset pos;
  int color;
  double size; // fraction of the page width
  bool bold;
  bool background;

  TextAnnot({
    required this.text,
    required this.pos,
    required this.color,
    required this.size,
    this.bold = false,
    this.background = false,
  });

  @override
  Map<String, dynamic> toJson() => {
        't': 'text',
        'x': text,
        'px': pos.dx,
        'py': pos.dy,
        'c': color,
        's': size,
        'b': bold,
        'bg': background,
      };

  @override
  void shift(Offset d) => pos = pos + d;

  TextPainter _layout(Size page) => TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: Color(color),
            fontSize: size * page.width,
            height: 1.25,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.rtl,
      )..layout(maxWidth: page.width * 0.9);

  @override
  Rect bounds(Size page) {
    final tp = _layout(page);
    return Rect.fromLTWH(pos.dx * page.width, pos.dy * page.height, tp.width, tp.height).inflate(4);
  }

  @override
  bool hit(Offset p, Size page, double tol) => bounds(page).inflate(tol).contains(p);
}

double _distToSegment(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
  if (len2 == 0) return (p - a).distance;
  final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2).clamp(0.0, 1.0);
  return (p - (a + ab * t)).distance;
}

class PageAnnotations {
  final List<Annot> items = [];
  bool get isEmpty => items.isEmpty;

  List<Map<String, dynamic>> snapshot() => [for (final a in items) a.toJson()];

  void restore(List<Map<String, dynamic>> snap) {
    items
      ..clear()
      ..addAll([for (final j in snap) Annot.fromJson(Map<String, dynamic>.from(j))].whereType<Annot>());
  }
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
      if (!p.isEmpty) out['$n'] = p.snapshot();
    });
    final f = _file(pdfPath);
    if (out.isEmpty) {
      if (await f.exists()) await f.delete();
    } else {
      await f.writeAsString(jsonEncode(out));
    }
  }
}

/// Bookmarked pages of one PDF, saved as `<file>.bm.json`.
class DocBookmarks {
  final Set<int> pages = {};

  static File _file(String pdfPath) => File('$pdfPath.bm.json');

  static Future<DocBookmarks> load(String pdfPath) async {
    final b = DocBookmarks();
    try {
      final f = _file(pdfPath);
      if (await f.exists()) {
        for (final v in jsonDecode(await f.readAsString()) as List<dynamic>) {
          b.pages.add((v as num).toInt());
        }
      }
    } catch (_) {}
    return b;
  }

  Future<void> save(String pdfPath) async {
    final f = _file(pdfPath);
    if (pages.isEmpty) {
      if (await f.exists()) await f.delete();
    } else {
      await f.writeAsString(jsonEncode(pages.toList()..sort()));
    }
  }
}

/// Paints the annotations of a page on a canvas of [size].
class AnnotationPainter extends CustomPainter {
  final List<Annot> items;
  final Annot? current;
  final Annot? selected;

  AnnotationPainter(this.items, {this.current, this.selected});

  @override
  void paint(Canvas canvas, Size size) {
    for (final a in items) {
      draw(canvas, size, a);
    }
    if (current != null) draw(canvas, size, current!);
    final sel = selected;
    if (sel != null) {
      final r = sel.bounds(size).inflate(3);
      final line = Paint()
        ..color = const Color(0xFF2563EB)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      _dashedPath(Path()..addRRect(RRect.fromRectAndRadius(r, const Radius.circular(6))), 6, 4, canvas, line);
      canvas.drawCircle(r.topLeft, 4, Paint()..color = const Color(0xFF2563EB));
      canvas.drawCircle(r.bottomRight, 4, Paint()..color = const Color(0xFF2563EB));
    }
  }

  static void draw(Canvas canvas, Size size, Annot a) {
    if (a is StrokeAnnot) {
      _stroke(canvas, size, a);
    } else if (a is ShapeAnnot) {
      _shape(canvas, size, a);
    } else if (a is TextAnnot) {
      final tp = a._layout(size);
      final at = Offset(a.pos.dx * size.width, a.pos.dy * size.height);
      if (a.background) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(at.dx - 3, at.dy - 1, tp.width + 6, tp.height + 2), const Radius.circular(4)),
          Paint()..color = const Color(0xFFFDE047).withOpacity(0.55),
        );
      }
      tp.paint(canvas, at);
    }
  }

  // ---- strokes -------------------------------------------------------------

  static void _stroke(Canvas canvas, Size size, StrokeAnnot a) {
    if (a.points.isEmpty) return;
    final pts = [for (final p in a.points) Offset(p.dx * size.width, p.dy * size.height)];
    final w = a.width * size.width;
    final base = Color(a.color);

    Paint paint(double width, {double alpha = 1.0, StrokeCap cap = StrokeCap.round}) => Paint()
      ..color = base.withOpacity((a.opacity * alpha).clamp(0.0, 1.0))
      ..strokeWidth = math.max(0.5, width)
      ..strokeCap = cap
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    if (pts.length == 1) {
      canvas.drawCircle(pts.first, math.max(0.5, w) / 2, paint(w)..style = PaintingStyle.fill);
      return;
    }

    switch (a.pen) {
      case PenKind.ballpoint:
        canvas.drawPath(_smooth(pts), paint(w));
      case PenKind.marker:
        canvas.drawPath(_smooth(pts), paint(w * 2.2, alpha: 0.9));
      case PenKind.highlighter:
        canvas.drawPath(_smooth(pts), paint(w * 5, alpha: 0.35, cap: StrokeCap.butt));
      case PenKind.pencil:
        final path = _smooth(pts);
        canvas.drawPath(path, paint(w * 0.9, alpha: 0.55));
        // A second, offset pass gives the grainy look of graphite.
        canvas.drawPath(path.shift(Offset(w * 0.18, -w * 0.12)), paint(w * 0.55, alpha: 0.45));
        canvas.drawPath(path.shift(Offset(-w * 0.15, w * 0.14)), paint(w * 0.45, alpha: 0.35));
      case PenKind.neon:
        final path = _smooth(pts);
        canvas.drawPath(
          path,
          paint(w * 3.2, alpha: 0.55)..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(1.0, w * 1.4)),
        );
        canvas.drawPath(path, paint(w * 1.3));
        canvas.drawPath(
          path,
          Paint()
            ..color = Color.lerp(base, const Color(0xFFFFFFFF), 0.75)!.withOpacity(a.opacity)
            ..strokeWidth = math.max(0.5, w * 0.5)
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..style = PaintingStyle.stroke,
        );
      case PenKind.dashed:
        _dashedPath(_smooth(pts), w * 3, w * 2.2, canvas, paint(w * 1.1));
      case PenKind.fountain:
        _variable(canvas, pts, a, paint, w, 0.55, 1.35);
      case PenKind.brush:
        _variable(canvas, pts, a, paint, w * 1.6, 0.25, 1.9);
    }
  }

  /// Draws a stroke whose thickness follows the pressure (stylus) or the
  /// drawing speed (finger): slow = thick, fast = thin, like ink or a brush.
  static void _variable(Canvas canvas, List<Offset> pts, StrokeAnnot a,
      Paint Function(double, {double alpha, StrokeCap cap}) paint, double w, double lo, double hi) {
    final pr = a.pressures;
    var cur = w;
    for (var i = 1; i < pts.length; i++) {
      double target;
      if (pr != null && pr.length == pts.length) {
        target = w * (lo + (hi - lo) * pr[i].clamp(0.0, 1.0));
      } else {
        final speed = ((pts[i] - pts[i - 1]).distance / math.max(1.0, w * 1.6)).clamp(0.0, 1.0);
        target = w * (hi - (hi - lo) * speed);
      }
      cur += (target - cur) * 0.35;
      canvas.drawLine(pts[i - 1], pts[i], paint(cur));
    }
  }

  static Path _smooth(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    if (pts.length < 3) {
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      return path;
    }
    for (var i = 1; i < pts.length - 1; i++) {
      final mid = Offset((pts[i].dx + pts[i + 1].dx) / 2, (pts[i].dy + pts[i + 1].dy) / 2);
      path.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(pts.last.dx, pts.last.dy);
    return path;
  }

  static void _dashedPath(Path path, double on, double off, Canvas canvas, Paint paint) {
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, math.min(d + on, m.length)), paint);
        d += on + off;
      }
    }
  }

  // ---- shapes --------------------------------------------------------------

  static void _shape(Canvas canvas, Size size, ShapeAnnot s) {
    final pa = Offset(s.a.dx * size.width, s.a.dy * size.height);
    final pb = Offset(s.b.dx * size.width, s.b.dy * size.height);
    final w = math.max(0.8, s.width * size.width);
    final base = Color(s.color);
    final stroke = Paint()
      ..color = base.withOpacity(s.opacity.clamp(0.0, 1.0))
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    final rect = Rect.fromPoints(pa, pb);

    switch (s.kind) {
      case ShapeKind.line:
        canvas.drawLine(pa, pb, stroke);
      case ShapeKind.arrow:
        canvas.drawLine(pa, pb, stroke);
        final ang = math.atan2(pb.dy - pa.dy, pb.dx - pa.dx);
        final head = math.max(w * 4.5, 14.0);
        for (final da in [math.pi - 0.45, math.pi + 0.45]) {
          canvas.drawLine(pb, pb + Offset(math.cos(ang + da), math.sin(ang + da)) * head, stroke);
        }
      case ShapeKind.rect:
        if (s.fill) {
          canvas.drawRect(rect, Paint()..color = base.withOpacity(0.18 * s.opacity));
        }
        canvas.drawRect(rect, stroke);
      case ShapeKind.ellipse:
        if (s.fill) {
          canvas.drawOval(rect, Paint()..color = base.withOpacity(0.18 * s.opacity));
        }
        canvas.drawOval(rect, stroke);
      case ShapeKind.box:
        canvas.drawRect(rect, Paint()..color = base.withOpacity(0.35 * s.opacity));
    }
  }

  @override
  bool shouldRepaint(covariant AnnotationPainter old) => true;
}
