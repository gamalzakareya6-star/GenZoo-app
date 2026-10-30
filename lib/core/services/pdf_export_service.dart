import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:pdf/pdf.dart' as pdflib;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as px;

import '../../models/pdf_annotations.dart';

/// Builds a new PDF in which the user's drawings and notes are burned into
/// the pages (so any PDF viewer shows them).
///
/// Each page is rendered to an image, the annotations are painted over it and
/// the result becomes a page of the new file. Text in the exported copy is
/// therefore not selectable.
class PdfExportService {
  static Future<File> export({
    required String sourcePath,
    required DocAnnotations annotations,
    required File target,
    void Function(int done, int total)? onProgress,
  }) async {
    final doc = await px.PdfDocument.openFile(sourcePath);
    final out = pw.Document();
    try {
      final total = doc.pagesCount;
      for (var n = 1; n <= total; n++) {
        final page = await doc.getPage(n);
        late final double pageW;
        late final double pageH;
        late final List<int> bytes;
        try {
          pageW = page.width;
          pageH = page.height;
          final annotated = !(annotations.pages[n]?.isEmpty ?? true);
          final targetW = annotated ? 1200.0 : 1400.0;
          final scale = (targetW / pageW).clamp(1.0, 3.0);
          final w = (pageW * scale).roundToDouble();
          final h = (pageH * scale).roundToDouble();
          final img = await page.render(
            width: w,
            height: h,
            format: px.PdfPageImageFormat.jpeg,
            backgroundColor: '#FFFFFF',
            quality: 85,
          );
          if (img == null) throw 'تعذّر رسم الصفحة $n';
          bytes = annotated
              ? await _burn(img.bytes, annotations.pages[n]!, w.toInt(), h.toInt())
              : img.bytes;
        } finally {
          await page.close();
        }

        final image = pw.MemoryImage(Uint8List.fromList(bytes));
        out.addPage(
          pw.Page(
            pageFormat: pdflib.PdfPageFormat(pageW, pageH),
            margin: pw.EdgeInsets.zero,
            build: (_) => pw.Image(image, fit: pw.BoxFit.fill),
          ),
        );
        onProgress?.call(n, total);
      }
    } finally {
      await doc.close();
    }

    await target.parent.create(recursive: true);
    await target.writeAsBytes(await out.save(), flush: true);
    return target;
  }

  static Future<List<int>> _burn(
      List<int> base, PageAnnotations annots, int w, int h) async {
    final codec = await ui.instantiateImageCodec(Uint8List.fromList(base));
    final frame = await codec.getNextFrame();
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImage(frame.image, ui.Offset.zero, ui.Paint());
    AnnotationPainter(annots.items).paint(canvas, ui.Size(w.toDouble(), h.toDouble()));
    final picture = recorder.endRecording();
    final merged = await picture.toImage(w, h);
    final data = await merged.toByteData(format: ui.ImageByteFormat.png);
    frame.image.dispose();
    merged.dispose();
    return data!.buffer.asUint8List();
  }
}
