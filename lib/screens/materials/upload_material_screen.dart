import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/materials_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';

class UploadMaterialScreen extends StatefulWidget {
  const UploadMaterialScreen({super.key});

  @override
  State<UploadMaterialScreen> createState() => _UploadMaterialScreenState();
}

class _UploadMaterialScreenState extends State<UploadMaterialScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _linkController = TextEditingController();
  String _fileType = 'pdf';
  static const _fileTypes = ['pdf', 'docx', 'pptx', 'xlsx', 'zip', 'other'];

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  String _selectedYear = AppConstants.academicYears.first;
  String _selectedSemester = AppConstants.semesters.first;
  String _selectedType = AppConstants.materialTypes.first;

  @override
  void dispose() {
    _linkController.dispose();
    _titleController.dispose();
    _subjectController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submitUpload() async {
    if (!_formKey.currentState!.validate()) return;

    final user = Provider.of<UserAuthProvider>(context, listen: false).user;
    final materialsProvider = Provider.of<MaterialsProvider>(context, listen: false);

    final success = await materialsProvider.addMaterialLink(
      fileUrl: _linkController.text.trim(),
      fileExtension: _fileType,
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      academicYear: _selectedYear,
      semester: _selectedSemester,
      subject: _subjectController.text.trim(),
      materialType: _selectedType,
      uploaderName: user?.displayName ?? 'الإدارة',
    );

    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم نشر المادة بنجاح!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final materialsProvider = Provider.of<MaterialsProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة مادة دراسية'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Link to the file (Google Drive, OneDrive, Mega, ...)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.primary),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'ارفع الملف على Google Drive واضبط المشاركة على "أي شخص لديه الرابط"، '
                          'ثم الصق الرابط هنا.',
                          style: TextStyle(fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _linkController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'رابط الملف *',
                    hintText: 'https://drive.google.com/file/d/...',
                    prefixIcon: Icon(Icons.link_rounded),
                  ),
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    final uri = Uri.tryParse(t);
                    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https') || uri.host.isEmpty) {
                      return 'من فضلك الصق رابطًا صحيحًا (https://...)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _fileType,
                  decoration: const InputDecoration(
                    labelText: 'نوع الملف',
                    prefixIcon: Icon(Icons.insert_drive_file_outlined),
                  ),
                  items: _fileTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase())))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _fileType = val);
                  },
                ),
                const SizedBox(height: 24),

                // Metadata Form Fields
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'عنوان المادة *',
                    hintText: 'مثال: المحاضرة 3 - الحبليات',
                    prefixIcon: Icon(Icons.title),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'من فضلك أدخل العنوان' : null,
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _subjectController,
                  decoration: const InputDecoration(
                    labelText: 'اسم المقرر *',
                    hintText: 'مثال: حبليات 1',
                    prefixIcon: Icon(Icons.book_outlined),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'من فضلك أدخل اسم المقرر' : null,
                ),
                const SizedBox(height: 14),

                // Academic Year & Semester
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedYear,
                        decoration: const InputDecoration(labelText: 'الفرقة الدراسية'),
                        isExpanded: true,
                        items: AppConstants.academicYears.map((year) {
                          return DropdownMenuItem(
                            value: year,
                            child: Text(year, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedYear = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedSemester,
                        decoration: const InputDecoration(labelText: 'الفصل الدراسي'),
                        isExpanded: true,
                        items: AppConstants.semesters.map((sem) {
                          return DropdownMenuItem(
                            value: sem,
                            child: Text(sem, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedSemester = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                DropdownButtonFormField<String>(
                  value: _selectedType,
                  decoration: const InputDecoration(
                    labelText: 'نوع المادة',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: AppConstants.materialTypes.map((type) {
                    return DropdownMenuItem(value: type, child: Text(type));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedType = val);
                  },
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _descController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات / ملخص (اختياري)',
                    hintText: 'ملخص مختصر للمحتوى أو ملاحظات المحاضر...',
                  ),
                ),
                const SizedBox(height: 28),

                ElevatedButton.icon(
                  onPressed: materialsProvider.isUploading ? null : _submitUpload,
                  icon: const Icon(Icons.publish_rounded),
                  label: Text(
                    materialsProvider.isUploading ? 'جارٍ النشر...' : 'نشر للطلاب',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
