import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart' as px;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/pdf_export_service.dart';
import '../../models/offline_file.dart';
import '../../models/pdf_annotations.dart';
import '../../providers/downloads_provider.dart';

enum _Tool { move, pen, highlighter, text, eraser }

class _PageImg {
  final Uint8List bytes;
  final double w;
  final double h;
  _PageImg(this.bytes, this.w, this.h);
}

/// Opens a downloaded PDF: reads page by page (pinch to zoom), remembers the
/// last page, lets the user draw / highlight / type on top of it and export
/// a new PDF that contains those edits.
class PdfReaderScreen extends StatefulWidget {
  final OfflineFile file;
  const PdfReaderScreen({super.key, required this.file});

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  px.PdfDocument? _doc;
  PageController? _pc;
  String? _error;
  int _pages = 0;
  int _current = 1;

  final TransformationController _tc = TransformationController();
  bool _zoomed = false;

  final Map<int, Future<_PageImg>> _cache = {};

  DocAnnotations _ann = DocAnnotations();
  bool _editing = false;
  _Tool _tool = _Tool.pen;
  int _color = 0xFFDC2626;
  double _width = 0.004; // fraction of page width
  StrokeAnnot? _stroke;
  Timer? _saveTimer;
  bool _exporting = false;

  static const _penColors = [0xFF111827, 0xFFDC2626, 0xFF2563EB, 0xFF16A34A, 0xFF7C3AED, 0xFFEA580C];
  static const _markColors = [0xFFFDE047, 0xFF67E8F9, 0xFF86EFAC, 0xFFF9A8D4, 0xFFFDBA74];

  String get _path => widget.file.path;

  @override
  void initState() {
    super.initState();
    _tc.addListener(_onZoom);
    _open();
  }

  Future<void> _open() async {
    try {
      final doc = await px.PdfDocument.openFile(_path);
      final ann = await DocAnnotations.load(_path);
      final start = widget.file.lastPage.clamp(1, doc.pagesCount);
      if (!mounted) {
        await doc.close();
        return;
      }
      setState(() {
        _doc = doc;
        _ann = ann;
        _pages = doc.pagesCount;
        _current = start;
        _pc = PageController(initialPage: start - 1);
      });
      if (start > 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('تابعت من الصفحة $start'),
            duration: const Duration(seconds: 2),
          ));
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذّر فتح الملف. قد يكون تالفاً أو محمياً.\n$e');
    }
  }

  void _onZoom() {
    final z = _tc.value.getMaxScaleOnAxis() > 1.03;
    if (z != _zoomed) setState(() => _zoomed = z);
  }

  Future<_PageImg> _render(int n) {
    return _cache.putIfAbsent(n, () async {
      final page = await _doc!.getPage(n);
      try {
        final scale = (1500 / page.width).clamp(1.0, 3.0);
        final img = await page.render(
          width: page.width * scale,
          height: page.height * scale,
          format: px.PdfPageImageFormat.jpeg,
          backgroundColor: '#FFFFFF',
          quality: 90,
        );
        if (img == null) throw 'تعذّر رسم الصفحة';
        return _PageImg(img.bytes, page.width, page.height);
      } finally {
        await page.close();
      }
    });
  }

  void _evict() {
    _cache.removeWhere((n, _) => (n - _current).abs() > 2);
  }

  void _onPageChanged(int i) {
    _tc.value = Matrix4.identity();
    setState(() {
      _current = i + 1;
      _stroke = null;
    });
    _evict();
    context.read<DownloadsProvider>().setLastPage(widget.file.id, _current);
  }

  // ---- annotations -------------------------------------------------------

  void _changed() {
    setState(() {});
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), () => _ann.save(_path));
  }

  Offset _norm(Offset p, Size s) =>
      Offset((p.dx / s.width).clamp(0.0, 1.0), (p.dy / s.height).clamp(0.0, 1.0));

  void _panStart(Offset p, Size s) {
    if (_tool == _Tool.pen || _tool == _Tool.highlighter) {
      final mark = _tool == _Tool.highlighter;
      setState(() {
        _stroke = StrokeAnnot(
          highlight: mark,
          color: _color,
          width: mark ? _width * 4.5 : _width,
          points: [_norm(p, s)],
        );
      });
    } else if (_tool == _Tool.eraser) {
      _erase(p, s);
    }
  }

  void _panUpdate(Offset p, Size s) {
    if (_stroke != null) {
      setState(() => _stroke!.points.add(_norm(p, s)));
    } else if (_tool == _Tool.eraser) {
      _erase(p, s);
    }
  }

  void _panEnd() {
    final st = _stroke;
    if (st != null) {
      _ann.page(_current).items.add(st);
      _stroke = null;
      _changed();
    }
  }

  void _erase(Offset p, Size s) {
    final items = _ann.page(_current).items;
    final before = items.length;
    items.removeWhere((a) {
      if (a is StrokeAnnot) {
        return a.points.any((q) => (Offset(q.dx * s.width, q.dy * s.height) - p).distance < 22);
      }
      if (a is TextAnnot) {
        final r = Rect.fromLTWH(a.pos.dx * s.width, a.pos.dy * s.height, s.width * 0.5, a.size * s.width * 1.6);
        return r.inflate(10).contains(p);
      }
      return false;
    });
    if (items.length != before) _changed();
  }

  Future<void> _addText(Offset p, Size s) async {
    final c = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة نص'),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'اكتب هنا...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('إضافة')),
        ],
      ),
    );
    if (text == null || text.isEmpty) return;
    _ann.page(_current).items.add(TextAnnot(
          text: text,
          pos: _norm(p, s),
          color: _color,
          size: 0.03 + (_width - 0.002) * 2.5,
        ));
    _changed();
  }

  void _undo() {
    final items = _ann.page(_current).items;
    if (items.isEmpty) return;
    items.removeLast();
    _changed();
  }

  void _selectTool(_Tool t) {
    HapticFeedback.selectionClick();
    setState(() {
      _tool = t;
      if (t == _Tool.highlighter && !_markColors.contains(_color)) _color = _markColors.first;
      if ((t == _Tool.pen || t == _Tool.text) && !_penColors.contains(_color)) _color = _penColors[1];
    });
  }

  // ---- export / share ----------------------------------------------------

  Future<void> _shareOriginal() async {
    await Share.shareXFiles([XFile(_path)], text: widget.file.title);
  }

  Future<void> _exportEdited() async {
    if (!_ann.hasAny) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد تعديلات لتصديرها بعد. استخدم أدوات التعديل أولاً.')),
      );
      return;
    }
    await _ann.save(_path);
    setState(() => _exporting = true);
    final downloads = context.read<DownloadsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final dir = await downloads.exportsDir();
      final safe = widget.file.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final target = File('${dir.path}/${safe}_معدل_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await PdfExportService.export(sourcePath: _path, annotations: _ann, target: target);
      await downloads.addExport(file: target, title: '${widget.file.title} (معدّل)');
      if (!mounted) return;
      setState(() => _exporting = false);
      _afterExport(target);
    } catch (e) {
      if (mounted) setState(() => _exporting = false);
      messenger.showSnackBar(SnackBar(content: Text('تعذّر التصدير: $e')));
    }
  }

  void _afterExport(File target) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              leading: Icon(Icons.check_circle_rounded, color: AppColors.secondary),
              title: Text('تم حفظ نسخة معدّلة في "تحميلاتي"'),
              subtitle: Text('الملف الجديد يحتوي تعديلاتك ويُفتح في أي تطبيق PDF.'),
            ),
            ListTile(
              leading: const Icon(Icons.ios_share_rounded),
              title: const Text('مشاركة'),
              onTap: () async {
                Navigator.pop(ctx);
                await Share.shareXFiles([XFile(target.path)], text: widget.file.title);
              },
            ),
            ListTile(
              leading: const Icon(Icons.save_alt_rounded),
              title: const Text('حفظ في مكان على الجهاز'),
              onTap: () async {
                Navigator.pop(ctx);
                final bytes = await target.readAsBytes();
                final saved = await FilePicker.platform.saveFile(
                  dialogTitle: 'اختر مكان الحفظ',
                  fileName: '${widget.file.title}_معدل.pdf',
                  bytes: bytes,
                  type: FileType.custom,
                  allowedExtensions: const ['pdf'],
                );
                if (saved != null && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحفظ.')));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _jump() async {
    final c = TextEditingController(text: '$_current');
    final p = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('الانتقال إلى صفحة'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: 'من 1 إلى $_pages'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, int.tryParse(c.text)), child: const Text('انتقال')),
        ],
      ),
    );
    if (p != null && p >= 1 && p <= _pages) _pc?.jumpToPage(p - 1);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _ann.save(_path);
    _tc.dispose();
    _pc?.dispose();
    _doc?.close();
    super.dispose();
  }

  // ---- UI ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.file.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16)),
            if (_pages > 0)
              Text('صفحة $_current من $_pages', style: TextStyle(fontSize: 11, color: theme.hintColor)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _editing ? 'إنهاء التعديل' : 'تعديل / كتابة',
            icon: Icon(_editing ? Icons.check_rounded : Icons.edit_rounded,
                color: _editing ? AppColors.secondary : null),
            onPressed: _doc == null
                ? null
                : () {
                    setState(() {
                      _editing = !_editing;
                      _stroke = null;
                      if (_editing) _tc.value = Matrix4.identity();
                    });
                    if (!_editing) _ann.save(_path);
                  },
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'jump') _jump();
              if (v == 'export') _exportEdited();
              if (v == 'share') _shareOriginal();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'jump', child: Text('الانتقال لصفحة')),
              PopupMenuItem(value: 'export', child: Text('تصدير نسخة معدّلة (PDF)')),
              PopupMenuItem(value: 'share', child: Text('مشاركة الملف الأصلي')),
            ],
          ),
        ],
      ),
      body: _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
          : _pc == null
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  children: [
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: PageView.builder(
                        controller: _pc,
                        itemCount: _pages,
                        physics: (_editing || _zoomed)
                            ? const NeverScrollableScrollPhysics()
                            : const PageScrollPhysics(),
                        onPageChanged: _onPageChanged,
                        itemBuilder: (_, i) => _buildPage(i + 1),
                      ),
                    ),
                    if (_exporting)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black45,
                          child: const Center(
                            child: Card(
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 12),
                                    Text('جارٍ إنشاء النسخة المعدّلة...'),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (_editing) Positioned(left: 12, right: 12, bottom: 12, child: _toolbar(theme)),
                  ],
                ),
    );
  }

  Widget _buildPage(int n) {
    return FutureBuilder<_PageImg>(
      future: _render(n),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('تعذّر عرض الصفحة $n'));
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final img = snap.data!;
        return LayoutBuilder(builder: (context, box) {
          final avail = Size(box.maxWidth, box.maxHeight - (_editing ? 96 : 0));
          final ratio = img.w / img.h;
          var w = avail.width;
          var h = w / ratio;
          if (h > avail.height) {
            h = avail.height;
            w = h * ratio;
          }
          final size = Size(w, h);
          final isCurrent = n == _current;
          final content = SizedBox(
            width: w,
            height: h,
            child: Stack(
              children: [
                Positioned.fill(child: Image.memory(img.bytes, fit: BoxFit.fill, gaplessPlayback: true)),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: AnnotationPainter(
                        _ann.pages[n]?.items ?? const [],
                        current: isCurrent ? _stroke : null,
                      ),
                    ),
                  ),
                ),
                if (_editing && isCurrent && _tool != _Tool.move)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (d) => _panStart(d.localPosition, size),
                      onPanUpdate: (d) => _panUpdate(d.localPosition, size),
                      onPanEnd: (_) => _panEnd(),
                      onTapUp: (d) {
                        if (_tool == _Tool.text) _addText(d.localPosition, size);
                        if (_tool == _Tool.eraser) _erase(d.localPosition, size);
                        if (_tool == _Tool.pen || _tool == _Tool.highlighter) {
                          _panStart(d.localPosition, size);
                          _panEnd();
                        }
                      },
                    ),
                  ),
              ],
            ),
          );
          return Center(
            child: InteractiveViewer(
              transformationController: isCurrent ? _tc : null,
              minScale: 1,
              maxScale: 5,
              panEnabled: !_editing,
              scaleEnabled: !_editing,
              child: content,
            ),
          );
        });
      },
    );
  }

  Widget _toolbar(ThemeData theme) {
    Widget toolBtn(_Tool t, IconData icon, String label) {
      final sel = _tool == t;
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _selectTool(t),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: sel ? AppColors.primary.withOpacity(0.12) : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 20, color: sel ? AppColors.primary : theme.hintColor),
            Text(label, style: TextStyle(fontSize: 10, color: sel ? AppColors.primary : theme.hintColor)),
          ]),
        ),
      );
    }

    final colors = _tool == _Tool.highlighter ? _markColors : _penColors;
    final showStyle = _tool == _Tool.pen || _tool == _Tool.highlighter || _tool == _Tool.text;
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(18),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            toolBtn(_Tool.pen, Icons.edit_rounded, 'قلم'),
            toolBtn(_Tool.highlighter, Icons.border_color_rounded, 'تظليل'),
            toolBtn(_Tool.text, Icons.text_fields_rounded, 'نص'),
            toolBtn(_Tool.eraser, Icons.cleaning_services_rounded, 'ممحاة'),
            IconButton(icon: const Icon(Icons.undo_rounded), tooltip: 'تراجع', onPressed: _undo),
          ]),
          if (showStyle)
            Row(children: [
              for (final c in colors)
                GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 26,
                    height: 26,
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _color == c ? AppColors.primary : Colors.grey.shade400,
                        width: _color == c ? 3 : 1,
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: Slider(
                  value: _width,
                  min: 0.002,
                  max: 0.012,
                  onChanged: (v) => setState(() => _width = v),
                ),
              ),
            ]),
        ]),
      ),
    );
  }
}
