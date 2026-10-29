import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/file_storage_service.dart';

enum AnnotationTool { pen, highlighter, text, eraser }

/// A single drawing stroke consisting of multiple points
class DrawingStroke {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  final bool isHighlighter;

  DrawingStroke({
    required this.points,
    required this.color,
    required this.strokeWidth,
    this.isHighlighter = false,
  });

  Map<String, dynamic> toJson() => {
        'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
        'color': color.value,
        'strokeWidth': strokeWidth,
        'isHighlighter': isHighlighter,
      };

  factory DrawingStroke.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'] as List<dynamic>? ?? [];
    final points = rawPoints.map((p) {
      final map = p as Map<String, dynamic>;
      return Offset(
        (map['x'] as num).toDouble(),
        (map['y'] as num).toDouble(),
      );
    }).toList();

    return DrawingStroke(
      points: points,
      color: Color(json['color'] as int? ?? 0xFF000000),
      strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 3.0,
      isHighlighter: json['isHighlighter'] as bool? ?? false,
    );
  }
}

/// A text note annotation placed on a page
class TextNote {
  Offset position;
  String text;
  Color color;
  double fontSize;

  TextNote({
    required this.position,
    required this.text,
    this.color = Colors.black,
    this.fontSize = 14.0,
  });

  Map<String, dynamic> toJson() => {
        'x': position.dx,
        'y': position.dy,
        'text': text,
        'color': color.value,
        'fontSize': fontSize,
      };

  factory TextNote.fromJson(Map<String, dynamic> json) => TextNote(
        position: Offset(
          (json['x'] as num).toDouble(),
          (json['y'] as num).toDouble(),
        ),
        text: json['text'] as String? ?? '',
        color: Color(json['color'] as int? ?? 0xFF000000),
        fontSize: (json['fontSize'] as num?)?.toDouble() ?? 14.0,
      );
}

/// Rich in-app PDF Reader and Annotation Editor
class PdfViewerScreen extends StatefulWidget {
  final String filePath;
  final String title;
  final String subject;
  final String department;

  const PdfViewerScreen({
    super.key,
    required this.filePath,
    required this.title,
    this.subject = '',
    this.department = '',
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  PdfControllerPinch? _pdfController;
  bool _isLoading = true;
  String? _errorMessage;

  int _currentPage = 1;
  int _totalPages = 1;

  // Edit / Annotation Mode State
  bool _isEditingMode = false;
  AnnotationTool _currentTool = AnnotationTool.pen;
  Color _selectedColor = const Color(0xFF1E293B);
  double _strokeWidth = 3.5;

  // Annotations organized by page number: Map<int, List<DrawingStroke>>
  final Map<int, List<DrawingStroke>> _pageStrokes = {};
  // Text notes organized by page number: Map<int, List<TextNote>>
  final Map<int, List<TextNote>> _pageTextNotes = {};

  // Current active stroke while dragging
  DrawingStroke? _currentStroke;

  final List<Color> _penColors = [
    const Color(0xFF0F172A), // Dark Navy
    const Color(0xFFDC2626), // Red
    const Color(0xFF2563EB), // Blue
    const Color(0xFF16A34A), // Green
    const Color(0xFFD97706), // Amber
    const Color(0xFF7C3AED), // Purple
  ];

  final List<Color> _highlighterColors = [
    const Color(0xFFFDE047), // Yellow
    const Color(0xFF67E8F9), // Cyan
    const Color(0xFF86EFAC), // Mint
    const Color(0xFFF472B6), // Pink
  ];

  @override
  void initState() {
    super.initState();
    _initPdf();
  }

  Future<void> _initPdf() async {
    try {
      // 1. Retrieve last read page
      final savedPage = await FileStorageService.getLastReadPage(widget.filePath);

      // 2. Load stored annotations
      await _loadSavedAnnotations();

      // 3. Initialize PDF controller
      _pdfController = PdfControllerPinch(
        document: PdfDocument.openFile(widget.filePath),
        initialPage: savedPage,
      );

      if (mounted) {
        setState(() {
          _currentPage = savedPage;
          _isLoading = false;
        });

        if (savedPage > 1) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم استئناف القراءة من صفحة $savedPage'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'تعذر فتح ملف الـ PDF: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadSavedAnnotations() async {
    final data = await FileStorageService.loadAnnotations(widget.filePath);
    if (data == null) return;

    if (data['strokes'] != null) {
      final strokesMap = data['strokes'] as Map<String, dynamic>;
      strokesMap.forEach((pageStr, list) {
        final pageNum = int.tryParse(pageStr) ?? 1;
        final strokeList = (list as List<dynamic>)
            .map((s) => DrawingStroke.fromJson(s as Map<String, dynamic>))
            .toList();
        _pageStrokes[pageNum] = strokeList;
      });
    }

    if (data['notes'] != null) {
      final notesMap = data['notes'] as Map<String, dynamic>;
      notesMap.forEach((pageStr, list) {
        final pageNum = int.tryParse(pageStr) ?? 1;
        final notesList = (list as List<dynamic>)
            .map((n) => TextNote.fromJson(n as Map<String, dynamic>))
            .toList();
        _pageTextNotes[pageNum] = notesList;
      });
    }
  }

  Future<void> _saveAnnotations() async {
    final strokesJson = <String, dynamic>{};
    _pageStrokes.forEach((page, list) {
      if (list.isNotEmpty) {
        strokesJson[page.toString()] = list.map((s) => s.toJson()).toList();
      }
    });

    final notesJson = <String, dynamic>{};
    _pageTextNotes.forEach((page, list) {
      if (list.isNotEmpty) {
        notesJson[page.toString()] = list.map((n) => n.toJson()).toList();
      }
    });

    final data = {
      'strokes': strokesJson,
      'notes': notesJson,
      'updatedAt': DateTime.now().toIso8601String(),
    };

    await FileStorageService.saveAnnotations(widget.filePath, data);
  }

  @override
  void dispose() {
    _saveAnnotations();
    _pdfController?.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
    // Save where the user left off
    FileStorageService.saveLastReadPage(widget.filePath, page);
  }

  void _jumpToPage(int page) {
    if (_pdfController != null && page >= 1 && page <= _totalPages) {
      _pdfController!.animateToPage(
        pageNumber: page,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showJumpDialog() {
    final controller = TextEditingController(text: '$_currentPage');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('انتقل إلى صفحة'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'من 1 إلى $_totalPages',
            labelText: 'رقم الصفحة',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              final p = int.tryParse(controller.text);
              if (p != null && p >= 1 && p <= _totalPages) {
                Navigator.pop(ctx);
                _jumpToPage(p);
              }
            },
            child: const Text('انتقال'),
          ),
        ],
      ),
    );
  }

  Future<void> _shareFile() async {
    try {
      await _saveAnnotations();
      await Share.shareXFiles(
        [XFile(widget.filePath)],
        text: 'مشاركة ملف: ${widget.title}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر مشاركة الملف: $e')),
        );
      }
    }
  }

  Future<void> _saveEditedCopy() async {
    try {
      await _saveAnnotations();

      final strokesJson = <String, dynamic>{};
      _pageStrokes.forEach((page, list) {
        if (list.isNotEmpty) {
          strokesJson[page.toString()] = list.map((s) => s.toJson()).toList();
        }
      });

      final notesJson = <String, dynamic>{};
      _pageTextNotes.forEach((page, list) {
        if (list.isNotEmpty) {
          notesJson[page.toString()] = list.map((n) => n.toJson()).toList();
        }
      });

      final data = {
        'strokes': strokesJson,
        'notes': notesJson,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      await FileStorageService.saveEditedCopy(
        originalPath: widget.filePath,
        originalTitle: widget.title,
        subject: widget.subject,
        department: widget.department,
        annotationsData: data,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.secondary,
            content: Text('✓ تم حفظ نسخة معدلة بنجاح في مكتبة أوفلاين!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حفظ النسخة المعدلة: $e')),
        );
      }
    }
  }

  void _addTextNoteDialog(Offset position) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة ملاحظة نصية'),
        content: TextField(
          controller: textController,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'اكتب ملاحظتك هنا...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = textController.text.trim();
              if (text.isNotEmpty) {
                setState(() {
                  _pageTextNotes.putIfAbsent(_currentPage, () => []);
                  _pageTextNotes[_currentPage]!.add(
                    TextNote(
                      position: position,
                      text: text,
                      color: _selectedColor,
                    ),
                  );
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  void _undo() {
    setState(() {
      if (_currentTool == AnnotationTool.text) {
        if (_pageTextNotes[_currentPage]?.isNotEmpty ?? false) {
          _pageTextNotes[_currentPage]!.removeLast();
        }
      } else {
        if (_pageStrokes[_currentPage]?.isNotEmpty ?? false) {
          _pageStrokes[_currentPage]!.removeLast();
        }
      }
    });
  }

  void _clearCurrentPage() {
    setState(() {
      _pageStrokes[_currentPage]?.clear();
      _pageTextNotes[_currentPage]?.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'صفحة $_currentPage من $_totalPages • ${widget.subject}',
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withOpacity(0.65),
              ),
            ),
          ],
        ),
        actions: [
          // Jump to page
          IconButton(
            icon: const Icon(Icons.pin_drop_outlined),
            tooltip: 'الانتقال لصفحة',
            onPressed: _showJumpDialog,
          ),

          // Toggle Mode (Reading vs Annotate/Draw)
          IconButton(
            icon: Icon(
              _isEditingMode
                  ? Icons.menu_book_rounded
                  : Icons.edit_note_rounded,
              color: _isEditingMode ? AppColors.secondary : null,
            ),
            tooltip: _isEditingMode ? 'العودة لوضع القراءة' : 'وضع التعديل والكتابة',
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() {
                _isEditingMode = !_isEditingMode;
              });
              if (!_isEditingMode) {
                _saveAnnotations();
              }
            },
          ),

          // More Options Menu (Share, Save Copy)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) {
              if (val == 'share') _shareFile();
              if (val == 'save_copy') _saveEditedCopy();
              if (val == 'save_annotations') {
                _saveAnnotations();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✓ تم حفظ التعديلات بنجاح'),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'save_annotations',
                child: Row(
                  children: [
                    Icon(Icons.save_outlined, size: 20),
                    SizedBox(width: 10),
                    Text('حفظ التعديلات'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'save_copy',
                child: Row(
                  children: [
                    Icon(Icons.copy_rounded, size: 20),
                    SizedBox(width: 10),
                    Text('حفظ نسخة معدلة مستقلة'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share_outlined, size: 20),
                    SizedBox(width: 10),
                    Text('مشاركة وتصدير'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: AppColors.error),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('رجوع'),
                        ),
                      ],
                    ),
                  ),
                )
              : Stack(
                  children: [
                    // PDF View Pinch
                    PdfViewPinch(
                      controller: _pdfController!,
                      onPageChanged: _onPageChanged,
                      onDocumentLoaded: (doc) {
                        setState(() {
                          _totalPages = doc.pagesCount;
                        });
                      },
                      onDocumentError: (error) {
                        setState(() {
                          _errorMessage = 'خطأ أثناء عرض المستند: $error';
                        });
                      },
                    ),

                    // Drawing & Text Annotation Canvas Overlay
                    Positioned.fill(
                      child: IgnorePointer(
                        ignoring: !_isEditingMode,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapUp: (details) {
                            if (_isEditingMode &&
                                _currentTool == AnnotationTool.text) {
                              _addTextNoteDialog(details.localPosition);
                            }
                          },
                          onPanStart: (details) {
                            if (!_isEditingMode) return;
                            if (_currentTool == AnnotationTool.text) return;

                            if (_currentTool == AnnotationTool.eraser) {
                              _eraseAt(details.localPosition);
                              return;
                            }

                            final isHighlighter =
                                _currentTool == AnnotationTool.highlighter;
                            setState(() {
                              _currentStroke = DrawingStroke(
                                points: [details.localPosition],
                                color: isHighlighter
                                    ? _selectedColor.withOpacity(0.4)
                                    : _selectedColor,
                                strokeWidth: isHighlighter
                                    ? _strokeWidth * 3.5
                                    : _strokeWidth,
                                isHighlighter: isHighlighter,
                              );
                            });
                          },
                          onPanUpdate: (details) {
                            if (!_isEditingMode) return;
                            if (_currentTool == AnnotationTool.text) return;

                            if (_currentTool == AnnotationTool.eraser) {
                              _eraseAt(details.localPosition);
                              return;
                            }

                            if (_currentStroke != null) {
                              setState(() {
                                _currentStroke!.points
                                    .add(details.localPosition);
                              });
                            }
                          },
                          onPanEnd: (_) {
                            if (_currentStroke != null) {
                              setState(() {
                                _pageStrokes.putIfAbsent(_currentPage, () => []);
                                _pageStrokes[_currentPage]!.add(_currentStroke!);
                                _currentStroke = null;
                              });
                            }
                          },
                          child: CustomPaint(
                            painter: _AnnotationPainter(
                              strokes: _pageStrokes[_currentPage] ?? [],
                              currentStroke: _currentStroke,
                              notes: _pageTextNotes[_currentPage] ?? [],
                            ),
                            child: Container(),
                          ),
                        ),
                      ),
                    ),

                    // Floating Bottom Annotation Toolbar (When in Edit Mode)
                    if (_isEditingMode)
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: _buildAnnotationToolbar(theme),
                      ),

                    // Page Navigation Pill (When in Reading Mode)
                    if (!_isEditingMode)
                      Positioned(
                        bottom: 20,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface.withOpacity(0.92),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.chevron_right, size: 20),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: _currentPage > 1
                                      ? () => _jumpToPage(_currentPage - 1)
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: _showJumpDialog,
                                  child: Text(
                                    '$_currentPage / $_totalPages',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.chevron_left, size: 20),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: _currentPage < _totalPages
                                      ? () => _jumpToPage(_currentPage + 1)
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }

  void _eraseAt(Offset pos) {
    final strokes = _pageStrokes[_currentPage];
    if (strokes == null || strokes.isEmpty) return;

    setState(() {
      strokes.removeWhere((stroke) {
        return stroke.points.any((p) => (p - pos).distance < 20);
      });
    });
  }

  Widget _buildAnnotationToolbar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tools Row: Pen, Highlighter, Text, Eraser, Undo, Clear
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildToolButton(
                tool: AnnotationTool.pen,
                icon: Icons.edit_rounded,
                label: 'قلم',
              ),
              _buildToolButton(
                tool: AnnotationTool.highlighter,
                icon: Icons.brush_rounded,
                label: 'تظليل',
              ),
              _buildToolButton(
                tool: AnnotationTool.text,
                icon: Icons.title_rounded,
                label: 'نص',
              ),
              _buildToolButton(
                tool: AnnotationTool.eraser,
                icon: Icons.auto_fix_high_rounded,
                label: 'ممحاة',
              ),
              IconButton(
                icon: const Icon(Icons.undo_rounded, size: 20),
                tooltip: 'تراجع',
                onPressed: _undo,
              ),
              IconButton(
                icon: const Icon(Icons.delete_sweep_rounded, size: 20),
                tooltip: 'مسح الصفحة',
                onPressed: _clearCurrentPage,
              ),
            ],
          ),

          if (_currentTool == AnnotationTool.pen ||
              _currentTool == AnnotationTool.highlighter) ...[
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Color Swatches Row
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 28,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: (_currentTool == AnnotationTool.highlighter
                              ? _highlighterColors
                              : _penColors)
                          .map((c) {
                        final isSelected = _selectedColor.value == c.value;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedColor = c);
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.grey.shade400,
                                width: isSelected ? 2.5 : 1,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check,
                                    size: 16, color: Colors.white)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                // Thickness slider
                SizedBox(
                  width: 100,
                  child: Slider(
                    value: _strokeWidth,
                    min: 1.5,
                    max: 8.0,
                    onChanged: (val) => setState(() => _strokeWidth = val),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildToolButton({
    required AnnotationTool tool,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _currentTool == tool;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _currentTool = tool;
          if (tool == AnnotationTool.highlighter) {
            _selectedColor = _highlighterColors.first;
          } else if (tool == AnnotationTool.pen) {
            _selectedColor = _penColors.first;
          }
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: AppColors.primary, width: 1.5)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppColors.primary : Colors.grey.shade600,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.primary : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for rendering page strokes and text annotations
class _AnnotationPainter extends CustomPainter {
  final List<DrawingStroke> strokes;
  final DrawingStroke? currentStroke;
  final List<TextNote> notes;

  _AnnotationPainter({
    required this.strokes,
    this.currentStroke,
    required this.notes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw saved strokes
    for (final stroke in strokes) {
      _paintStroke(canvas, stroke);
    }

    // 2. Draw current active stroke
    if (currentStroke != null) {
      _paintStroke(canvas, currentStroke!);
    }

    // 3. Draw text notes
    for (final note in notes) {
      final textSpan = TextSpan(
        text: note.text,
        style: TextStyle(
          color: note.color,
          fontSize: note.fontSize,
          backgroundColor: Colors.amber.shade100.withOpacity(0.85),
          fontWeight: FontWeight.w600,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.rtl,
      );
      textPainter.layout(maxWidth: size.width - note.position.dx);
      textPainter.paint(canvas, note.position);
    }
  }

  void _paintStroke(Canvas canvas, DrawingStroke stroke) {
    if (stroke.points.isEmpty) return;

    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(stroke.points.first.dx, stroke.points.first.dy);

    for (int i = 1; i < stroke.points.length; i++) {
      path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _AnnotationPainter oldDelegate) => true;
}
