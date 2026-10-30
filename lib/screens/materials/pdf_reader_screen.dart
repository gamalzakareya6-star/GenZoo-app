import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
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
import '../../widgets/animations.dart';
import 'pdf_tools_ui.dart';

enum _Tool { hand, select, pen, shape, text, eraser }

class _PageImg {
  final Uint8List bytes;
  final double w;
  final double h;
  _PageImg(this.bytes, this.w, this.h);
}

class _Snap {
  final int page;
  final List<Map<String, dynamic>> items;
  _Snap(this.page, this.items);
}

/// In-app PDF reader and editor.
///
/// Reading: page by page, double-tap / pinch zoom, slider, thumbnails,
/// bookmarks, night mode and "continue where you stopped".
/// Editing: 8 pens, shapes, text and stamps, select & move, eraser,
/// undo/redo, stylus pressure, and export of a new PDF with the edits.
class PdfReaderScreen extends StatefulWidget {
  final OfflineFile file;
  const PdfReaderScreen({super.key, required this.file});

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> with SingleTickerProviderStateMixin {
  px.PdfDocument? _doc;
  PageController? _pc;
  String? _error;
  int _pages = 0;
  int _current = 1;

  final TransformationController _tc = TransformationController();
  bool _zoomed = false;
  late final AnimationController _zoomAnim =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 260));

  final Map<int, Future<_PageImg>> _cache = {};
  final Map<int, Future<Uint8List?>> _thumbs = {};
  Future<void> _chain = Future.value();

  DocAnnotations _ann = DocAnnotations();
  DocBookmarks _bm = DocBookmarks();

  bool _editing = false;
  bool _bars = true;
  bool _night = false;
  bool _stylusOnly = false;
  bool _exporting = false;

  // Tools
  _Tool _tool = _Tool.pen;
  PenKind _pen = PenKind.ballpoint;
  ShapeKind _shape = ShapeKind.arrow;
  final Map<PenKind, int> _penColor = {...defaultPenColors};
  final Map<PenKind, double> _penWidth = {for (final s in penSpecs) s.kind: s.defaultWidth};
  final Map<PenKind, double> _penOpacity = {for (final s in penSpecs) s.kind: 1.0};
  int _shapeColor = 0xFFDC2626;
  double _shapeWidth = 0.004;
  bool _shapeFill = false;
  int _textColor = 0xFF111827;
  double _textSize = 0.035;
  bool _textBold = false;
  bool _textBg = false;
  String? _stamp;

  // Live gesture state
  Annot? _live;
  Annot? _selected;
  int? _pointer;
  List<double>? _pressures;
  Offset? _lastNorm;
  Offset? _downPos;
  bool _movedItem = false;
  bool _erasedInGesture = false;
  Offset? _doubleTapAt;
  VoidCallback? _zoomTick;

  final List<_Snap> _undo = [];
  final List<_Snap> _redo = [];
  Timer? _saveTimer;

  static const _quickColors = [
    0xFF111827, 0xFFDC2626, 0xFFF97316, 0xFFFACC15, 0xFF16A34A, 0xFF0D9488, 0xFF2563EB, 0xFF7C3AED, 0xFFEC4899, 0xFFFFFFFF,
  ];
  static const _stamps = ['✓', '✗', '★', '!', '?', '←', '→'];

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
      final bm = await DocBookmarks.load(_path);
      final start = widget.file.lastPage.clamp(1, doc.pagesCount);
      if (!mounted) {
        await doc.close();
        return;
      }
      setState(() {
        _doc = doc;
        _ann = ann;
        _bm = bm;
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

  // ---- rendering (one page at a time: some devices allow only one open page)

  Future<T> _serial<T>(Future<T> Function() task) {
    final c = Completer<T>();
    _chain = _chain.then((_) async {
      try {
        c.complete(await task());
      } catch (e, st) {
        c.completeError(e, st);
      }
    });
    return c.future;
  }

  Future<_PageImg> _render(int n) {
    return _cache.putIfAbsent(n, () {
      return _serial(() async {
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
    });
  }

  Future<Uint8List?> _thumb(int n) {
    return _thumbs.putIfAbsent(n, () {
      return _serial<Uint8List?>(() async {
        final page = await _doc!.getPage(n);
        try {
          final img = await page.render(
            width: 240,
            height: 240 * page.height / page.width,
            format: px.PdfPageImageFormat.jpeg,
            backgroundColor: '#FFFFFF',
            quality: 70,
          );
          return img?.bytes;
        } finally {
          await page.close();
        }
      });
    });
  }

  void _evict() {
    _cache.removeWhere((n, _) => (n - _current).abs() > 2);
  }

  void _onPageChanged(int i) {
    _tc.value = Matrix4.identity();
    setState(() {
      _current = i + 1;
      _live = null;
      _selected = null;
    });
    _evict();
    context.read<DownloadsProvider>().setLastPage(widget.file.id, _current);
  }

  // ---- history -------------------------------------------------------------

  void _pushUndo() {
    _undo.add(_Snap(_current, _ann.page(_current).snapshot()));
    if (_undo.length > 80) _undo.removeAt(0);
    _redo.clear();
  }

  void _undoAction() {
    if (_undo.isEmpty) return;
    final s = _undo.removeLast();
    final pa = _ann.page(s.page);
    _redo.add(_Snap(s.page, pa.snapshot()));
    pa.restore(s.items);
    _selected = null;
    if (s.page != _current) _pc?.jumpToPage(s.page - 1);
    _changed();
  }

  void _redoAction() {
    if (_redo.isEmpty) return;
    final s = _redo.removeLast();
    final pa = _ann.page(s.page);
    _undo.add(_Snap(s.page, pa.snapshot()));
    pa.restore(s.items);
    _selected = null;
    if (s.page != _current) _pc?.jumpToPage(s.page - 1);
    _changed();
  }

  void _changed() {
    setState(() {});
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), () => _ann.save(_path));
  }

  // ---- drawing -------------------------------------------------------------

  Offset _norm(Offset p, Size s) =>
      Offset((p.dx / s.width).clamp(0.0, 1.0), (p.dy / s.height).clamp(0.0, 1.0));

  int get _color => switch (_tool) {
        _Tool.pen => _penColor[_pen]!,
        _Tool.shape => _shapeColor,
        _Tool.text => _textColor,
        _ => _selected != null ? _colorOf(_selected!) : _textColor,
      };

  int _colorOf(Annot a) {
    if (a is StrokeAnnot) return a.color;
    if (a is ShapeAnnot) return a.color;
    if (a is TextAnnot) return a.color;
    return _textColor;
  }

  void _setColor(int c) {
    HapticFeedback.selectionClick();
    setState(() {
      switch (_tool) {
        case _Tool.pen:
          _penColor[_pen] = c;
        case _Tool.shape:
          _shapeColor = c;
        case _Tool.text:
          _textColor = c;
        case _Tool.select:
          _recolor(c);
        default:
          break;
      }
      recentPdfColors.remove(c);
      recentPdfColors.insert(0, c);
      if (recentPdfColors.length > 5) recentPdfColors.removeLast();
    });
  }

  void _recolor(int c) {
    final sel = _selected;
    if (sel == null) return;
    final items = _ann.page(_current).items;
    final i = items.indexOf(sel);
    if (i < 0) return;
    _pushUndo();
    final j = sel.toJson()..['c'] = c;
    final fresh = Annot.fromJson(j)!;
    items[i] = fresh;
    _selected = fresh;
    _changed();
  }

  void _pointerDown(PointerDownEvent e, Size s) {
    if (_pointer != null) return;
    if (_stylusOnly && e.kind != PointerDeviceKind.stylus) return;
    _pointer = e.pointer;
    final pos = e.localPosition;
    final n = _norm(pos, s);
    _downPos = pos;
    _movedItem = false;
    _erasedInGesture = false;

    switch (_tool) {
      case _Tool.pen:
        final stylus = e.kind == PointerDeviceKind.stylus;
        _pressures = stylus ? [_pressureOf(e)] : null;
        _live = StrokeAnnot(
          pen: _pen,
          color: _penColor[_pen]!,
          width: _penWidth[_pen]!,
          opacity: _penOpacity[_pen]!,
          points: [n],
          pressures: _pressures,
        );
      case _Tool.shape:
        _live = ShapeAnnot(
          kind: _shape,
          a: n,
          b: n,
          color: _shapeColor,
          width: _shapeWidth,
          opacity: 1,
          fill: _shapeFill,
        );
      case _Tool.eraser:
        _eraseAt(pos, s);
      case _Tool.select:
        final items = _ann.page(_current).items;
        Annot? found;
        for (final a in items.reversed) {
          if (a.hit(pos, s, 14)) {
            found = a;
            break;
          }
        }
        _selected = found;
        _lastNorm = n;
      case _Tool.text:
      case _Tool.hand:
        break;
    }
    setState(() {});
  }

  double _pressureOf(PointerEvent e) {
    final range = e.pressureMax - e.pressureMin;
    if (range <= 0) return 0.5;
    return ((e.pressure - e.pressureMin) / range).clamp(0.0, 1.0);
  }

  void _pointerMove(PointerMoveEvent e, Size s) {
    if (e.pointer != _pointer) return;
    final pos = e.localPosition;
    final n = _norm(pos, s);
    switch (_tool) {
      case _Tool.pen:
        final st = _live as StrokeAnnot?;
        if (st == null) return;
        st.points.add(n);
        _pressures?.add(_pressureOf(e));
        setState(() {});
      case _Tool.shape:
        final sh = _live as ShapeAnnot?;
        if (sh == null) return;
        sh.b = n;
        setState(() {});
      case _Tool.eraser:
        _eraseAt(pos, s);
      case _Tool.select:
        final sel = _selected;
        final last = _lastNorm;
        if (sel == null || last == null) return;
        if (!_movedItem) {
          if ((pos - _downPos!).distance < 6) return; // ignore tiny jitter
          _pushUndo();
          _movedItem = true;
        }
        sel.shift(n - last);
        _lastNorm = n;
        setState(() {});
      case _Tool.text:
      case _Tool.hand:
        break;
    }
  }

  void _pointerUp(PointerEvent e, Size s, {bool cancel = false}) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    final pos = e.localPosition;
    switch (_tool) {
      case _Tool.pen:
        final st = _live as StrokeAnnot?;
        _live = null;
        if (st != null && !cancel) {
          _pushUndo();
          _ann.page(_current).items.add(st);
          _changed();
        } else {
          setState(() {});
        }
      case _Tool.shape:
        final sh = _live as ShapeAnnot?;
        _live = null;
        final tiny = sh == null ||
            (Offset((sh.b.dx - sh.a.dx) * s.width, (sh.b.dy - sh.a.dy) * s.height)).distance < 5;
        if (!tiny && !cancel) {
          _pushUndo();
          _ann.page(_current).items.add(sh);
          _changed();
        } else {
          setState(() {});
        }
      case _Tool.select:
        if (_movedItem) _changed();
        setState(() {});
      case _Tool.text:
        if (!cancel && _downPos != null && (pos - _downPos!).distance < 10) {
          if (_stamp != null) {
            _placeText(_stamp!, pos, s, size: 0.07);
          } else {
            _askText(pos, s);
          }
        }
      case _Tool.eraser:
      case _Tool.hand:
        setState(() {});
    }
  }

  void _eraseAt(Offset p, Size s) {
    final items = _ann.page(_current).items;
    final victims = items.where((a) => a.hit(p, s, 12)).toList();
    if (victims.isEmpty) return;
    if (!_erasedInGesture) {
      _pushUndo();
      _erasedInGesture = true;
    }
    for (final v in victims) {
      items.remove(v);
      if (identical(v, _selected)) _selected = null;
    }
    HapticFeedback.selectionClick();
    _changed();
  }

  void _placeText(String text, Offset pos, Size s, {double? size}) {
    _pushUndo();
    _ann.page(_current).items.add(TextAnnot(
          text: text,
          pos: _norm(pos, s),
          color: _textColor,
          size: size ?? _textSize,
          bold: _textBold,
          background: _textBg,
        ));
    _changed();
  }

  Future<void> _askText(Offset pos, Size s, {TextAnnot? edit}) async {
    final c = TextEditingController(text: edit?.text ?? '');
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(edit == null ? 'إضافة نص' : 'تعديل النص'),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLines: 4,
          minLines: 1,
          decoration: const InputDecoration(hintText: 'اكتب هنا...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('تم')),
        ],
      ),
    );
    if (text == null || text.isEmpty) return;
    if (edit != null) {
      _pushUndo();
      edit.text = text;
      _changed();
    } else {
      _placeText(text, pos, s);
    }
  }

  void _deleteSelected() {
    final sel = _selected;
    if (sel == null) return;
    _pushUndo();
    _ann.page(_current).items.remove(sel);
    _selected = null;
    _changed();
  }

  void _duplicateSelected() {
    final sel = _selected;
    if (sel == null) return;
    _pushUndo();
    final copy = sel.clone()..shift(const Offset(0.03, 0.03));
    _ann.page(_current).items.add(copy);
    _selected = copy;
    _changed();
  }

  Future<void> _clearPage() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('مسح كل تعديلات هذه الصفحة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('مسح'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    _pushUndo();
    _ann.page(_current).items.clear();
    _selected = null;
    _changed();
  }

  // ---- zoom ----------------------------------------------------------------

  void _doubleTapZoom() {
    final at = _doubleTapAt;
    if (at == null) return;
    final m = _tc.value;
    final s0 = m.getMaxScaleOnAxis();
    final t0 = m.getTranslation();
    double s1, tx, ty;
    if (s0 > 1.05) {
      s1 = 1;
      tx = 0;
      ty = 0;
    } else {
      s1 = 2.6;
      tx = at.dx * (1 - s1);
      ty = at.dy * (1 - s1);
    }
    final old = _zoomTick;
    if (old != null) _zoomAnim.removeListener(old);
    _zoomAnim.reset();
    void tick() {
      final t = Curves.easeOutCubic.transform(_zoomAnim.value);
      final s = s0 + (s1 - s0) * t;
      final x = t0.x + (tx - t0.x) * t;
      final y = t0.y + (ty - t0.y) * t;
      _tc.value = Matrix4.identity()
        ..translate(x, y)
        ..scale(s);
    }

    _zoomTick = tick;
    _zoomAnim.addListener(tick);
    _zoomAnim.forward();
  }

  // ---- bookmarks / pages ---------------------------------------------------

  void _toggleBookmark() {
    HapticFeedback.lightImpact();
    setState(() {
      if (!_bm.pages.remove(_current)) _bm.pages.add(_current);
    });
    _bm.save(_path);
  }

  void _showThumbs() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        var onlyMarked = false;
        return StatefulBuilder(builder: (ctx, setSheet) {
          final pages = [
            for (var i = 1; i <= _pages; i++)
              if (!onlyMarked || _bm.pages.contains(i)) i,
          ];
          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            maxChildSize: 0.95,
            minChildSize: 0.4,
            expand: false,
            builder: (_, scroll) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('الصفحات ($_pages)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      FilterChip(
                        label: Text('المحفوظة فقط (${_bm.pages.length})'),
                        avatar: const Icon(Icons.bookmark_rounded, size: 16),
                        selected: onlyMarked,
                        onSelected: (v) => setSheet(() => onlyMarked = v),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: pages.isEmpty
                      ? const Center(child: Text('لا توجد صفحات محفوظة بعد.'))
                      : GridView.builder(
                          controller: scroll,
                          padding: const EdgeInsets.all(12),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 0.68,
                          ),
                          itemCount: pages.length,
                          itemBuilder: (_, i) => _thumbCell(ctx, pages[i]),
                        ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Widget _thumbCell(BuildContext sheetCtx, int n) {
    final isCur = n == _current;
    return GestureDetector(
      onTap: () {
        Navigator.pop(sheetCtx);
        _pc?.jumpToPage(n - 1);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isCur ? AppColors.primary : Colors.black12, width: isCur ? 3 : 1),
          color: Colors.white,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FutureBuilder<Uint8List?>(
              future: _thumb(n),
              builder: (_, snap) => snap.data == null
                  ? const SkeletonBox(height: 120, radius: 0)
                  : Image.memory(snap.data!, fit: BoxFit.cover, alignment: Alignment.topCenter),
            ),
            if (!(_ann.pages[n]?.isEmpty ?? true))
              const Positioned(
                top: 4,
                left: 4,
                child: Icon(Icons.edit_note_rounded, size: 18, color: AppColors.secondary),
              ),
            if (_bm.pages.contains(n))
              const Positioned(top: 0, right: 6, child: Icon(Icons.bookmark_rounded, color: Color(0xFFF59E0B), size: 26)),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 3),
                color: Colors.black54,
                child: Text('$n', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- export / share ------------------------------------------------------

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
    _zoomAnim.dispose();
    _tc.dispose();
    _pc?.dispose();
    _doc?.close();
    super.dispose();
  }

  // ---- UI ------------------------------------------------------------------

  bool get _drawingTool => _tool != _Tool.hand;
  bool get _canPanZoom => !_editing || _tool == _Tool.hand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final bg = _night ? const Color(0xFF0B0F19) : (dark ? const Color(0xFF111827) : const Color(0xFFE5E7EB));
    final showBars = _bars || _editing;

    return PopScope(
      canPop: !_editing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _editing) setState(() => _editing = false);
      },
      child: Scaffold(
        backgroundColor: bg,
        body: _error != null
            ? SafeArea(
                child: Center(
                  child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)),
                ),
              )
            : _pc == null
                ? const Center(child: CircularProgressIndicator())
                : Stack(
                    children: [
                      Positioned.fill(
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: PageView.builder(
                            controller: _pc,
                            itemCount: _pages,
                            physics: (_zoomed || (_editing && _drawingTool))
                                ? const NeverScrollableScrollPhysics()
                                : const PageScrollPhysics(),
                            onPageChanged: _onPageChanged,
                            itemBuilder: (_, i) => _buildPage(i + 1),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: AnimatedSlide(
                          offset: showBars ? Offset.zero : const Offset(0, -1.2),
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                          child: AnimatedOpacity(
                            opacity: showBars ? 1 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: _topBar(theme),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 10,
                        right: 10,
                        bottom: 0,
                        child: SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 260),
                              switchInCurve: Curves.easeOutCubic,
                              transitionBuilder: (child, anim) => FadeTransition(
                                opacity: anim,
                                child: SlideTransition(
                                  position: Tween(begin: const Offset(0, 0.35), end: Offset.zero).animate(anim),
                                  child: child,
                                ),
                              ),
                              child: _editing
                                  ? KeyedSubtree(key: const ValueKey('dock'), child: _editDock(theme))
                                  : (_bars
                                      ? KeyedSubtree(key: const ValueKey('slider'), child: _pageSlider(theme))
                                      : const SizedBox.shrink(key: ValueKey('none'))),
                            ),
                          ),
                        ),
                      ),
                      if (_exporting)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black54,
                            child: const Center(
                              child: Card(
                                child: Padding(
                                  padding: EdgeInsets.all(22),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircularProgressIndicator(),
                                      SizedBox(height: 14),
                                      Text('جارٍ إنشاء النسخة المعدّلة...'),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }

  Widget _glass({required Widget child, double radius = 20}) {
    final dark = Theme.of(context).brightness == Brightness.dark || _night;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: (dark ? const Color(0xFF1E293B) : Colors.white).withOpacity(0.9),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: (dark ? Colors.white : Colors.black).withOpacity(0.07)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 18, offset: const Offset(0, 6))],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _topBar(ThemeData theme) {
    final marked = _bm.pages.contains(_current);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
        child: _glass(
          radius: 18,
          child: Row(
            children: [
              if (_editing)
                IconButton(
                  tooltip: 'تم',
                  icon: const Icon(Icons.check_circle_rounded, color: AppColors.secondary),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _editing = false;
                      _live = null;
                      _selected = null;
                    });
                    _ann.save(_path);
                  },
                )
              else
                IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded),
                  tooltip: 'رجوع',
                  onPressed: () => Navigator.maybePop(context),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.file.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    if (_pages > 0)
                      Text('صفحة $_current من $_pages', style: TextStyle(fontSize: 11, color: theme.hintColor)),
                  ],
                ),
              ),
              if (_editing) ...[
                IconButton(
                  tooltip: 'تراجع',
                  icon: const Icon(Icons.undo_rounded),
                  onPressed: _undo.isEmpty ? null : _undoAction,
                ),
                IconButton(
                  tooltip: 'إعادة',
                  icon: const Icon(Icons.redo_rounded),
                  onPressed: _redo.isEmpty ? null : _redoAction,
                ),
              ] else ...[
                IconButton(
                  tooltip: marked ? 'إزالة العلامة' : 'حفظ الصفحة',
                  icon: Icon(marked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      color: marked ? const Color(0xFFF59E0B) : null),
                  onPressed: _doc == null ? null : _toggleBookmark,
                ),
                IconButton(
                  tooltip: _night ? 'الوضع العادي' : 'الوضع الليلي',
                  icon: Icon(_night ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
                  onPressed: () => setState(() => _night = !_night),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  child: IconButton(
                    tooltip: 'تعديل / كتابة',
                    icon: const Icon(Icons.edit_rounded, color: Colors.white),
                    onPressed: _doc == null
                        ? null
                        : () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              _editing = true;
                              _tc.value = Matrix4.identity();
                              _tool = _Tool.pen;
                            });
                          },
                  ),
                ),
              ],
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'thumbs') _showThumbs();
                  if (v == 'jump') _jump();
                  if (v == 'export') _exportEdited();
                  if (v == 'share') _shareOriginal();
                  if (v == 'clear') _clearPage();
                  if (v == 'stylus') setState(() => _stylusOnly = !_stylusOnly);
                  if (v == 'night') setState(() => _night = !_night);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'thumbs', child: ListTile(leading: Icon(Icons.grid_view_rounded), title: Text('كل الصفحات'), dense: true)),
                  const PopupMenuItem(value: 'jump', child: ListTile(leading: Icon(Icons.pin_drop_outlined), title: Text('الانتقال لصفحة'), dense: true)),
                  const PopupMenuItem(value: 'export', child: ListTile(leading: Icon(Icons.picture_as_pdf_rounded), title: Text('تصدير نسخة معدّلة'), dense: true)),
                  const PopupMenuItem(value: 'share', child: ListTile(leading: Icon(Icons.ios_share_rounded), title: Text('مشاركة الأصل'), dense: true)),
                  if (_editing) ...[
                    const PopupMenuItem(value: 'clear', child: ListTile(leading: Icon(Icons.layers_clear_rounded), title: Text('مسح تعديلات الصفحة'), dense: true)),
                    CheckedPopupMenuItem(value: 'stylus', checked: _stylusOnly, child: const Text('القلم فقط (تجاهل اللمس)')),
                    CheckedPopupMenuItem(value: 'night', checked: _night, child: const Text('الوضع الليلي')),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pageSlider(ThemeData theme) {
    return _glass(
      radius: 22,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: _current > 1 ? () => _pc?.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut) : null,
            ),
            Expanded(
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Slider(
                  value: _current.toDouble().clamp(1, _pages <= 1 ? 2 : _pages.toDouble()),
                  min: 1,
                  max: _pages <= 1 ? 2 : _pages.toDouble(),
                  divisions: _pages > 1 ? _pages - 1 : null,
                  label: '$_current',
                  onChanged: _pages <= 1 ? null : (v) => _pc?.jumpToPage(v.round() - 1),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: _current < _pages ? () => _pc?.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut) : null,
            ),
            IconButton(
              tooltip: 'كل الصفحات',
              icon: const Icon(Icons.grid_view_rounded),
              onPressed: _doc == null ? null : _showThumbs,
            ),
          ],
        ),
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
        if (!snap.hasData) {
          return const Center(child: SkeletonBox(width: 240, height: 340, radius: 8));
        }
        final img = snap.data!;
        return LayoutBuilder(builder: (context, box) {
          const topPad = 76.0;
          final bottomPad = _editing ? 210.0 : 84.0;
          final avail = Size(box.maxWidth - 16, box.maxHeight - topPad - bottomPad);
          final ratio = img.w / img.h;
          var w = avail.width;
          var h = w / ratio;
          if (h > avail.height) {
            h = avail.height;
            w = h * ratio;
          }
          final size = Size(w, h);
          final isCurrent = n == _current;

          Widget pageImage = Image.memory(img.bytes, fit: BoxFit.fill, gaplessPlayback: true);
          if (_night) {
            pageImage = ColorFiltered(
              colorFilter: const ColorFilter.matrix(<double>[
                -0.9, 0, 0, 0, 255, //
                0, -0.9, 0, 0, 255,
                0, 0, -0.9, 0, 255,
                0, 0, 0, 1, 0,
              ]),
              child: pageImage,
            );
          }

          final content = Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(_night ? 0.5 : 0.18), blurRadius: 14, offset: const Offset(0, 4))],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _editing ? null : () => setState(() => _bars = !_bars),
                    onDoubleTapDown: _canPanZoom ? (d) => _doubleTapAt = d.localPosition : null,
                    onDoubleTap: _canPanZoom ? _doubleTapZoom : null,
                    child: pageImage,
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: AnnotationPainter(
                        _ann.pages[n]?.items ?? const [],
                        current: isCurrent ? _live : null,
                        selected: isCurrent && _editing ? _selected : null,
                      ),
                    ),
                  ),
                ),
                if (_editing && isCurrent && _drawingTool)
                  Positioned.fill(
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (e) => _pointerDown(e, size),
                      onPointerMove: (e) => _pointerMove(e, size),
                      onPointerUp: (e) => _pointerUp(e, size),
                      onPointerCancel: (e) => _pointerUp(e, size, cancel: true),
                    ),
                  ),
              ],
            ),
          );
          return Center(
            child: Padding(
              padding: EdgeInsets.only(top: topPad - 8, bottom: bottomPad - 8),
              child: InteractiveViewer(
                transformationController: isCurrent ? _tc : null,
                minScale: 1,
                maxScale: 5,
                clipBehavior: Clip.none,
                panEnabled: _canPanZoom,
                scaleEnabled: _canPanZoom,
                child: content,
              ),
            ),
          );
        });
      },
    );
  }

  // ---- editing dock --------------------------------------------------------

  Widget _editDock(ThemeData theme) {
    return _glass(
      radius: 24,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              alignment: Alignment.bottomCenter,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: KeyedSubtree(
                  key: ValueKey('$_tool-$_pen-$_shape-${_selected != null}'),
                  child: _contextPanel(theme),
                ),
              ),
            ),
            const SizedBox(height: 4),
            _tray(theme),
          ],
        ),
      ),
    );
  }

  Widget _colorRow() {
    final cur = _color;
    final colors = <int>[..._quickColors, ...recentPdfColors.where((c) => !_quickColors.contains(c))];
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final c in colors)
            GestureDetector(
              onTap: () => _setColor(c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: cur == c ? 32 : 27,
                height: cur == c ? 32 : 27,
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Color(c),
                  shape: BoxShape.circle,
                  border: Border.all(color: cur == c ? AppColors.primary : Colors.black26, width: cur == c ? 3 : 1),
                  boxShadow: cur == c ? [BoxShadow(color: Color(c).withOpacity(0.5), blurRadius: 8)] : null,
                ),
              ),
            ),
          GestureDetector(
            onTap: () async {
              final c = await showPdfColorSheet(context, cur);
              if (c != null) _setColor(c);
            },
            child: Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(colors: [
                  Color(0xFFEF4444), Color(0xFFFACC15), Color(0xFF22C55E), Color(0xFF06B6D4), Color(0xFF3B82F6), Color(0xFFA855F7), Color(0xFFEF4444),
                ]),
              ),
              child: const Icon(Icons.add, size: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _labeledSlider(String label, double value, double min, double max, ValueChanged<double> on) {
    return Row(
      children: [
        SizedBox(width: 46, child: Text(label, style: const TextStyle(fontSize: 11))),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8)),
            child: Slider(value: value.clamp(min, max), min: min, max: max, onChanged: on),
          ),
        ),
      ],
    );
  }

  Widget _contextPanel(ThemeData theme) {
    switch (_tool) {
      case _Tool.hand:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Text('حرّك الصفحة وكبّرها بإصبعين، أو انقر مرتين للتكبير.', style: TextStyle(fontSize: 12)),
        );
      case _Tool.pen:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _colorRow(),
            Row(
              children: [
                StrokePreview(pen: _pen, color: _penColor[_pen]!, width: _penWidth[_pen]!, opacity: _penOpacity[_pen]!),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    children: [
                      _labeledSlider('السُمك', _penWidth[_pen]!, 0.0015, 0.016, (v) => setState(() => _penWidth[_pen] = v)),
                      _labeledSlider('الشفافية', _penOpacity[_pen]!, 0.15, 1, (v) => setState(() => _penOpacity[_pen] = v)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      case _Tool.shape:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _colorRow(),
            Row(
              children: [
                Expanded(child: _labeledSlider('السُمك', _shapeWidth, 0.0015, 0.016, (v) => setState(() => _shapeWidth = v))),
                if (_shape == ShapeKind.rect || _shape == ShapeKind.ellipse)
                  FilterChip(
                    label: const Text('تعبئة'),
                    selected: _shapeFill,
                    onSelected: (v) => setState(() => _shapeFill = v),
                  ),
              ],
            ),
          ],
        );
      case _Tool.text:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _colorRow(),
            Row(
              children: [
                Expanded(child: _labeledSlider('الحجم', _textSize, 0.02, 0.1, (v) => setState(() => _textSize = v))),
                FilterChip(label: const Text('عريض'), selected: _textBold, onSelected: (v) => setState(() => _textBold = v)),
                const SizedBox(width: 6),
                FilterChip(label: const Text('خلفية'), selected: _textBg, onSelected: (v) => setState(() => _textBg = v)),
              ],
            ),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final st in _stamps)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: ChoiceChip(
                        label: Text(st, style: const TextStyle(fontSize: 18)),
                        selected: _stamp == st,
                        onSelected: (v) => setState(() => _stamp = v ? st : null),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      case _Tool.eraser:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              const Expanded(child: Text('المس أي خط أو شكل أو نص لحذفه، أو اسحب فوقها.', style: TextStyle(fontSize: 12))),
              TextButton.icon(
                onPressed: _clearPage,
                icon: const Icon(Icons.layers_clear_rounded, size: 18),
                label: const Text('مسح الصفحة'),
              ),
            ],
          ),
        );
      case _Tool.select:
        final sel = _selected;
        if (sel == null) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text('المس أي عنصر لتحديده ثم اسحبه لنقله.', style: TextStyle(fontSize: 12)),
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _colorRow(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (sel is TextAnnot)
                  TextButton.icon(
                    onPressed: () => _askText(Offset.zero, const Size(1, 1), edit: sel),
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('تعديل'),
                  ),
                TextButton.icon(onPressed: _duplicateSelected, icon: const Icon(Icons.copy_rounded, size: 18), label: const Text('تكرار')),
                TextButton.icon(
                  onPressed: _deleteSelected,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                  label: const Text('حذف', style: TextStyle(color: AppColors.error)),
                ),
              ],
            ),
          ],
        );
    }
  }

  Widget _tray(ThemeData theme) {
    final dark = theme.brightness == Brightness.dark || _night;
    final idle = dark ? Colors.white70 : Colors.black54;

    Widget divider() => Container(width: 1, height: 44, margin: const EdgeInsets.symmetric(horizontal: 6), color: Colors.black12);

    Widget iconItem(IconData icon, String label, bool sel, VoidCallback on) {
      return GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          on();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 54,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: sel ? AppColors.primary.withOpacity(0.16) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: sel ? AppColors.primaryLight : Colors.transparent, width: 1.5),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedScale(scale: sel ? 1.2 : 1, duration: const Duration(milliseconds: 200), child: Icon(icon, size: 24, color: sel ? AppColors.primaryLight : idle)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: sel ? FontWeight.bold : FontWeight.w500, color: sel ? AppColors.primaryLight : idle)),
          ]),
        ),
      );
    }

    Widget penItem(PenSpec spec) {
      final sel = _tool == _Tool.pen && _pen == spec.kind;
      return GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _tool = _Tool.pen;
            _pen = spec.kind;
            _selected = null;
          });
        },
        child: Container(
          width: 46,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedSlide(
              offset: Offset(0, sel ? -0.18 : 0.1),
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutBack,
              child: PenIllustration(kind: spec.kind, color: Color(_penColor[spec.kind]!), selected: sel),
            ),
            Text(spec.label, style: TextStyle(fontSize: 10, fontWeight: sel ? FontWeight.bold : FontWeight.w500, color: sel ? AppColors.primaryLight : idle)),
          ]),
        ),
      );
    }

    return SizedBox(
      height: 84,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          iconItem(Icons.pan_tool_alt_rounded, 'تحريك', _tool == _Tool.hand, () => setState(() {
                _tool = _Tool.hand;
                _selected = null;
              })),
          iconItem(Icons.near_me_rounded, 'تحديد', _tool == _Tool.select, () => setState(() => _tool = _Tool.select)),
          divider(),
          for (final p in penSpecs) penItem(p),
          divider(),
          for (final sh in shapeSpecs)
            iconItem(sh.icon, sh.label, _tool == _Tool.shape && _shape == sh.kind, () => setState(() {
                  _tool = _Tool.shape;
                  _shape = sh.kind;
                  _selected = null;
                })),
          divider(),
          iconItem(Icons.text_fields_rounded, 'نص', _tool == _Tool.text, () => setState(() {
                _tool = _Tool.text;
                _selected = null;
              })),
          iconItem(Icons.cleaning_services_rounded, 'ممحاة', _tool == _Tool.eraser, () => setState(() {
                _tool = _Tool.eraser;
                _selected = null;
              })),
        ],
      ),
    );
  }
}
