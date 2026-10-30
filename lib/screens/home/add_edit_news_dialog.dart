import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/news_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../models/news_model.dart';
import '../../core/services/drive_upload_service.dart';
import '../../core/utils/drive_link.dart';

class AddEditNewsDialog extends StatefulWidget {
  /// When [item] is given the dialog edits that post instead of creating one.
  final NewsItem? item;

  const AddEditNewsDialog({super.key, this.item});

  @override
  State<AddEditNewsDialog> createState() => _AddEditNewsDialogState();
}

class _AddEditNewsDialogState extends State<AddEditNewsDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();

  String _selectedCategory = AppConstants.newsCategories.first;
  bool _isPinned = false;
  bool _isSubmitting = false;
  bool _isUploading = false;
  final List<UploadedFile> _attachments = [];
  final List<UploadedFile> _images = [];
  static const int _maxAttachments = 5;
  static const int _maxImages = 8;

  bool get _isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    if (item != null) {
      _titleController.text = item.title;
      _contentController.text = item.content;
      _linkController.text = item.externalUrl ?? '';
      _isPinned = item.isPinned;
      _attachments.addAll(item.attachments);
      _images.addAll(item.images);
      _selectedCategory = AppConstants.newsCategories.contains(item.category)
          ? item.category
          : AppConstants.newsCategories.first;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final remaining = _maxAttachments - _attachments.length;
    if (remaining <= 0) return;

    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null || !mounted) return;

    setState(() => _isUploading = true);
    final messenger = ScaffoldMessenger.of(context);
    for (final f in result.files.take(remaining)) {
      final path = f.path;
      if (path == null) continue;
      try {
        final uploaded = await DriveUploadService.upload(path, displayName: f.name);
        if (!mounted) return;
        setState(() => _attachments.add(uploaded));
      } catch (e) {
        messenger.showSnackBar(SnackBar(
          content: Text('${f.name}: $e'),
          backgroundColor: Colors.redAccent,
        ));
      }
    }
    if (mounted) setState(() => _isUploading = false);
  }

  Future<void> _pickImages() async {
    final remaining = _maxImages - _images.length;
    if (remaining <= 0) return;

    final result = await FilePicker.platform.pickFiles(allowMultiple: true, type: FileType.image);
    if (result == null || !mounted) return;

    setState(() => _isUploading = true);
    final messenger = ScaffoldMessenger.of(context);
    for (final f in result.files.take(remaining)) {
      final path = f.path;
      if (path == null) continue;
      try {
        final uploaded = await DriveUploadService.upload(path, displayName: f.name);
        if (!mounted) return;
        setState(() => _images.add(uploaded));
      } catch (e) {
        messenger.showSnackBar(SnackBar(
          content: Text('${f.name}: $e'),
          backgroundColor: Colors.redAccent,
        ));
      }
    }
    if (mounted) setState(() => _isUploading = false);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final user = Provider.of<UserAuthProvider>(context, listen: false).user;
    final newsProvider = Provider.of<NewsProvider>(context, listen: false);

    try {
      final link = _linkController.text.trim().isNotEmpty ? _linkController.text.trim() : null;
      if (_isEditing) {
        await newsProvider.updateNews(
          id: widget.item!.id,
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          category: _selectedCategory,
          isPinned: _isPinned,
          externalUrl: link,
          attachments: _attachments,
          images: _images,
        );
      } else {
        await newsProvider.addNews(
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          category: _selectedCategory,
          isPinned: _isPinned,
          authorName: user?.displayName ?? 'الإدارة',
          externalUrl: link,
          attachments: _attachments,
          images: _images,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'تم حفظ التعديل' : 'تم نشر الإعلان بنجاح!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل النشر: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.campaign_rounded, color: Colors.blue),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isEditing ? 'تعديل الإعلان' : 'إعلان جديد',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Category & Pin
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(labelText: 'التصنيف'),
                        items: AppConstants.newsCategories.map((c) {
                          return DropdownMenuItem(value: c, child: Text(c));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedCategory = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilterChip(
                      selected: _isPinned,
                      label: const Text('تثبيت في الأعلى'),
                      avatar: Icon(
                        _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                        size: 16,
                      ),
                      onSelected: (val) => setState(() => _isPinned = val),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'العنوان',
                    hintText: 'مثال: جدول امتحانات منتصف الفصل',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'من فضلك أدخل العنوان' : null,
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _contentController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'التفاصيل',
                    hintText: 'اكتب تفاصيل الإعلان هنا...',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'من فضلك أدخل التفاصيل' : null,
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _linkController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'رابط خارجي (اختياري)',
                    hintText: 'https://...',
                    prefixIcon: Icon(Icons.link),
                  ),
                ),
                const SizedBox(height: 14),

                // Pictures shown inside the post
                Row(
                  children: [
                    const Icon(Icons.photo_library_outlined, size: 18),
                    const SizedBox(width: 6),
                    Text('الصور (${_images.length}/$_maxImages)',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: (_isUploading || _images.length >= _maxImages) ? null : _pickImages,
                      icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                      label: const Text('إضافة صور'),
                    ),
                  ],
                ),
                if (_images.isNotEmpty)
                  SizedBox(
                    height: 78,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(top: 8),
                      children: [
                        for (final img in _images)
                          Stack(
                            children: [
                              Container(
                                width: 70,
                                height: 70,
                                margin: const EdgeInsets.only(left: 8),
                                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
                                clipBehavior: Clip.antiAlias,
                                child: Image.network(driveImageUrl(img.url, width: 300), fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined)),
                              ),
                              Positioned(
                                top: 0,
                                left: 0,
                                child: GestureDetector(
                                  onTap: () => setState(() => _images.remove(img)),
                                  child: const CircleAvatar(
                                    radius: 10,
                                    backgroundColor: Colors.black54,
                                    child: Icon(Icons.close, size: 12, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),

                // Attachments (stored in Google Drive)
                Row(
                  children: [
                    const Icon(Icons.attach_file, size: 18),
                    const SizedBox(width: 6),
                    Text('الملفات المرفقة (${_attachments.length}/$_maxAttachments)',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: (_isUploading || _attachments.length >= _maxAttachments)
                          ? null
                          : _pickFiles,
                      icon: _isUploading
                          ? const SizedBox(
                              width: 14, height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.upload_file, size: 18),
                      label: Text(_isUploading ? 'جارٍ الرفع...' : 'رفع ملف'),
                    ),
                  ],
                ),
                if (_attachments.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final f in _attachments)
                          InputChip(
                            label: Text(f.name, overflow: TextOverflow.ellipsis),
                            onDeleted: () => setState(() => _attachments.remove(f)),
                          ),
                      ],
                    ),
                  ),
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'الحد الأقصى 15 ميجابايت للملف. تُحفظ الملفات على Google Drive.',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                      child: const Text('إلغاء'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: (_isSubmitting || _isUploading) ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(_isEditing ? 'حفظ التعديل' : 'نشر الإعلان'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
