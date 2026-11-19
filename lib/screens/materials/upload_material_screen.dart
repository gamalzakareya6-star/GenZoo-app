import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/materials_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/drive_upload_service.dart';

class UploadMaterialScreen extends StatefulWidget {
  const UploadMaterialScreen({super.key});

  @override
  State<UploadMaterialScreen> createState() => _UploadMaterialScreenState();
}

class _UploadMaterialScreenState extends State<UploadMaterialScreen> {
  final _formKey = GlobalKey<FormState>();
  final _linkController = TextEditingController();
  final _titleController = TextEditingController();
  final _subjectController = TextEditingController();
  final _descController = TextEditingController();

  String _fileType = 'pdf';
  String _selectedDepartment = AppConstants.departments.first;
  String _selectedType = AppConstants.materialTypes.first;
  PlatformFile? _file;
  bool _useLink = false;
  bool _busy = false;

  @override
  void dispose() {
    _linkController.dispose();
    _titleController.dispose();
    _subjectController.dispose();
    _descController.dispose();
    progressNotifier.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(withData: false);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) {
      _snack('تعذر الوصول إلى الملف. اختره من ذاكرة الجهاز.', error: true);
      return;
    }
    if (file.size > DriveUploadService.maxBytes) {
      _snack('الحد الأقصى لحجم الملف 30 ميجابايت.', error: true);
      return;
    }
    setState(() {
      _file = file;
      if (_titleController.text.trim().isEmpty) {
        final dot = file.name.lastIndexOf('.');
        _titleController.text = dot > 0 ? file.name.substring(0, dot) : file.name;
      }
    });
  }

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? Colors.redAccent : Colors.green,
    ));
  }

  String _remaining(Duration d) {
    if (d.inSeconds <= 0) return 'جارٍ الإنهاء...';
    if (d.inMinutes > 0) return 'حوالي ${d.inMinutes} دقيقة و${d.inSeconds % 60} ثانية';
    return 'حوالي ${d.inSeconds} ثانية';
  }

  Future<void> _submitUpload() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_useLink && _file?.path == null) {
      _snack('اختر الملف المراد رفعه أولاً.', error: true);
      return;
    }

    setState(() => _busy = true);
    bool dialogOpen = false;
    var sentBytes = 0;
    var totalBytes = 0;
    var eta = 'جارٍ تجهيز الملف...';
    final stopwatch = Stopwatch()..start();

    if (!_useLink) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('جارٍ رفع الملف إلى Google Drive'),
            content: ValueListenableBuilder<int>(
              valueListenable: progressNotifier,
              builder: (context, value, child) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LinearProgressIndicator(value: totalBytes > 0 ? sentBytes / totalBytes : null),
                  const SizedBox(height: 14),
                  Text(totalBytes > 0 ? '${(sentBytes / totalBytes * 100).clamp(0, 100).toStringAsFixed(0)}%' : 'جارٍ بدء الرفع'),
                  const SizedBox(height: 6),
                  Text('تم إرسال ${(sentBytes / (1024 * 1024)).toStringAsFixed(1)} من ${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
                      style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 6),
                  Text('الوقت المتبقي: $eta', style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 8),
                  const Text('يرجى إبقاء التطبيق مفتوحًا حتى اكتمال الرفع.',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          ),
        ),
      );
      dialogOpen = true;
    }

    try {
      String fileUrl;
      String fileName;
      String extension;
      int fileSize;

      if (_useLink) {
        fileUrl = _linkController.text.trim();
        fileName = _titleController.text.trim();
        extension = _fileType;
        fileSize = 0;
      } else {
        final uploaded = await DriveUploadService.upload(
          _file!.path!,
          displayName: _file!.name,
          onProgress: (sent, total) {
            sentBytes = sent;
            totalBytes = total;
            if (sent > 0 && total > sent) {
              final seconds = stopwatch.elapsedMilliseconds / 1000;
              final speed = seconds > 0 ? sent / seconds : 0.0;
              if (speed > 0) eta = _remaining(Duration(seconds: ((total - sent) / speed).round()));
            } else if (sent >= total && total > 0) {
              eta = 'اكتمل إرسال البيانات، جارٍ حفظ الملف';
            }
            // The dialog rebuilds on the next progress tick through this notifier.
            progressNotifier.value = sent;
          },
        );
        fileUrl = uploaded.url;
        fileName = uploaded.name;
        fileSize = uploaded.size;
        final dot = uploaded.name.lastIndexOf('.');
        extension = dot >= 0 ? uploaded.name.substring(dot + 1).toLowerCase() : 'other';
      }

      final user = context.read<UserAuthProvider>().user;
      final success = await context.read<MaterialsProvider>().addMaterialLink(
        fileUrl: fileUrl,
        fileExtension: extension,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        department: _selectedDepartment,
        subject: _subjectController.text.trim(),
        materialType: _selectedType,
        uploaderName: user?.displayName ?? 'الإدارة',
        fileName: fileName,
        fileSizeBytes: fileSize,
      );

      if (dialogOpen && mounted) Navigator.of(context, rootNavigator: true).pop();
      if (!mounted) return;
      if (success) {
        Navigator.pop(context);
        _snack('تم رفع الملف ونشره للطلاب بنجاح.');
      } else {
        _snack(context.read<MaterialsProvider>().uploadError ?? 'تعذر نشر المادة.', error: true);
      }
    } catch (e) {
      if (dialogOpen && mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) _snack('$e', error: true);
    } finally {
      progressNotifier.value = 0;
      if (mounted) setState(() => _busy = false);
    }
  }

  final ValueNotifier<int> progressNotifier = ValueNotifier<int>(0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة مادة دراسية')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'يمكنك اختيار ملف من جهازك لرفعه مباشرة إلى Google Drive، أو إضافة رابط ملف موجود. الحد الأقصى للرفع المباشر 30 ميجابايت.',
                      style: TextStyle(fontSize: 12.5, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(label: const Text('رفع ملف من الجهاز'), selected: !_useLink,
                        onSelected: _busy ? null : (_) => setState(() => _useLink = false)),
                      ChoiceChip(label: const Text('إضافة رابط موجود'), selected: _useLink,
                        onSelected: _busy ? null : (_) => setState(() => _useLink = true)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_useLink) ...[
                    TextFormField(
                      controller: _linkController,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(labelText: 'رابط الملف *', hintText: 'https://drive.google.com/file/d/...', prefixIcon: Icon(Icons.link)),
                      validator: (v) {
                        if (!_useLink) return null;
                        final uri = Uri.tryParse(v?.trim() ?? '');
                        return uri == null || !['http', 'https'].contains(uri.scheme) || uri.host.isEmpty
                            ? 'أدخل رابطًا صحيحًا يبدأ بـ https://' : null;
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: _fileType,
                      decoration: const InputDecoration(labelText: 'امتداد الملف'),
                      items: ['pdf', 'docx', 'pptx', 'xlsx', 'zip', 'other']
                          .map((v) => DropdownMenuItem(value: v, child: Text(v.toUpperCase()))).toList(),
                      onChanged: (v) => setState(() => _fileType = v ?? _fileType),
                    ),
                  ] else ...[
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _pickFile,
                      icon: const Icon(Icons.upload_file),
                      label: Text(_file?.name ?? 'اختيار ملف من الجهاز (حتى 30 MB)', overflow: TextOverflow.ellipsis),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
                    ),
                    if (_file != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('الحجم: ${(_file!.size / (1024 * 1024)).toStringAsFixed(2)} MB',
                            style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ),
                  ],
                  const SizedBox(height: 20),
                  TextFormField(controller: _titleController, decoration: const InputDecoration(labelText: 'عنوان المادة *', prefixIcon: Icon(Icons.title)),
                    validator: (v) => v == null || v.trim().isEmpty ? 'أدخل عنوان المادة' : null),
                  const SizedBox(height: 14),
                  TextFormField(controller: _subjectController, decoration: const InputDecoration(labelText: 'اسم المقرر *', prefixIcon: Icon(Icons.book_outlined)),
                    validator: (v) => v == null || v.trim().isEmpty ? 'أدخل اسم المقرر' : null),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: _selectedDepartment, isExpanded: true,
                    decoration: const InputDecoration(labelText: 'القسم'),
                    items: AppConstants.departments.map((v) => DropdownMenuItem(value: v, child: Text(v, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) => setState(() => _selectedDepartment = v ?? _selectedDepartment),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: _selectedType,
                    decoration: const InputDecoration(labelText: 'نوع المادة'),
                    items: AppConstants.materialTypes.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                    onChanged: (v) => setState(() => _selectedType = v ?? _selectedType),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(controller: _descController, maxLines: 3, decoration: const InputDecoration(labelText: 'ملاحظات / ملخص (اختياري)')),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _busy ? null : _submitUpload,
                    icon: const Icon(Icons.publish_rounded),
                    label: Text(_busy ? 'جارٍ الرفع والنشر...' : 'رفع ونشر للطلاب'),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
