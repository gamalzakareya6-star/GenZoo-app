import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/news_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../models/news_model.dart';

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
        );
      } else {
        await newsProvider.addNews(
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          category: _selectedCategory,
          isPinned: _isPinned,
          authorName: user?.displayName ?? 'الإدارة',
          externalUrl: link,
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
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                      child: const Text('إلغاء'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
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
