import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/drive_upload_service.dart';
import '../../core/services/submission_service.dart';
import '../../models/submission_model.dart';
import '../../providers/auth_provider.dart';

/// A student sends a file; the admin must approve it before it appears in the
/// materials. The file itself is stored in Google Drive.
class SubmitMaterialScreen extends StatefulWidget {
  const SubmitMaterialScreen({super.key});

  @override
  State<SubmitMaterialScreen> createState() => _SubmitMaterialScreenState();
}

class _SubmitMaterialScreenState extends State<SubmitMaterialScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _subject = TextEditingController();
  final _desc = TextEditingController();
  String _department = AppConstants.departments.first;
  String _type = AppConstants.materialTypes.first;
  PlatformFile? _file;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _subject.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    if (f.size > DriveUploadService.maxBytes) {
      _snack('حجم الملف أكبر من 15 ميجابايت.', error: true);
      return;
    }
    setState(() {
      _file = f;
      if (_title.text.trim().isEmpty) {
        final dot = f.name.lastIndexOf('.');
        _title.text = dot > 0 ? f.name.substring(0, dot) : f.name;
      }
    });
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.redAccent : Colors.green,
    ));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final file = _file;
    if (file == null || file.path == null) {
      _snack('اختر الملف أولاً.', error: true);
      return;
    }
    final user = context.read<UserAuthProvider>().user;
    if (user == null || user.uid == 'guest') {
      _snack('سجّل الدخول لإرسال ملف.', error: true);
      return;
    }

    setState(() => _busy = true);
    try {
      final uploaded = await DriveUploadService.upload(file.path!, displayName: file.name);
      await SubmissionService.submit(
        uid: user.uid,
        submitterName: user.displayName,
        title: _title.text.trim(),
        description: _desc.text.trim(),
        department: _department,
        subject: _subject.text.trim(),
        materialType: _type,
        fileName: uploaded.name,
        fileUrl: uploaded.url,
        fileSize: uploaded.size,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تم إرسال الملف. سيظهر في المواد بعد موافقة المسؤول.'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _snack('$e', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<UserAuthProvider>().user?.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('المساهمة بملف')),
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
                      'ارفع ملف مفيد لزملائك (محاضرة، ملخص، امتحان سابق...). يراجعه المسؤول، '
                      'وبعد الموافقة يظهر في المواد باسمك. الحد الأقصى 15 ميجابايت.',
                      style: TextStyle(fontSize: 12.5, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _pick,
                    icon: const Icon(Icons.attach_file),
                    label: Text(_file == null ? 'اختر الملف *' : _file!.name,
                        overflow: TextOverflow.ellipsis),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _title,
                    decoration: const InputDecoration(labelText: 'عنوان الملف *', prefixIcon: Icon(Icons.title)),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'أدخل العنوان' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _subject,
                    decoration: const InputDecoration(
                      labelText: 'اسم المقرر *',
                      hintText: 'مثال: حبليات 1',
                      prefixIcon: Icon(Icons.book_outlined),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'أدخل اسم المقرر' : null,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: _department,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'القسم', prefixIcon: Icon(Icons.account_tree_outlined)),
                    items: AppConstants.departments
                        .map((d) => DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (v) => setState(() => _department = v ?? _department),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: _type,
                    decoration: const InputDecoration(labelText: 'نوع المادة', prefixIcon: Icon(Icons.category_outlined)),
                    items: AppConstants.materialTypes
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => setState(() => _type = v ?? _type),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _desc,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _busy ? null : _submit,
                    icon: _busy
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded),
                    label: Text(_busy ? 'جارٍ الرفع والإرسال...' : 'إرسال للمراجعة'),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  ),
                  const SizedBox(height: 28),
                  if (uid != null) _MySubmissions(uid: uid),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MySubmissions extends StatelessWidget {
  final String uid;
  const _MySubmissions({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MaterialSubmission>>(
      stream: SubmissionService.streamMine(uid),
      builder: (context, snap) {
        final list = snap.data ?? const <MaterialSubmission>[];
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('طلباتي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            for (final s in list)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  dense: true,
                  title: Text(s.title, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    s.status == 'rejected' && s.reviewNote.isNotEmpty
                        ? 'سبب الرفض: ${s.reviewNote}'
                        : s.subject,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: _StatusChip(status: s.status),
                  onLongPress: s.isPending
                      ? () async {
                          await SubmissionService.delete(s.id);
                        }
                      : null,
                ),
              ),
            const Text('اضغط مطولاً على طلب قيد المراجعة لإلغائه.',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'approved' => ('تم القبول', Colors.green),
      'rejected' => ('مرفوض', Colors.red),
      _ => ('قيد المراجعة', Colors.orange),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
    );
  }
}
