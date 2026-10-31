import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import 'dart:typed_data';

import '../../core/services/avatar_service.dart';
import '../../core/utils/phone.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/user_avatar.dart';

/// ملفي الشخصي: photo, name, phone, bio, year and department.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _bio;
  String? _year;
  String? _dept;
  String? _photo;
  Uint8List? _newBytes;
  bool _removePhoto = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final u = context.read<UserAuthProvider>().user;
    _name = TextEditingController(text: u?.displayName ?? '');
    _phone = TextEditingController(text: u?.phone ?? '');
    _bio = TextEditingController(text: u?.bio ?? '');
    _year = AppConstants.academicYears.contains(u?.academicYear) ? u?.academicYear : null;
    _dept = AppConstants.departments.contains(u?.department) ? u?.department : null;
    _photo = u?.photoUrl;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _bio.dispose();
    super.dispose();
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _pickPhoto() async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.image);
    final path = picked?.files.single.path;
    if (path == null) return;
    setState(() => _busy = true);
    try {
      final bytes = await AvatarService.prepare(path);
      setState(() {
        _newBytes = bytes;
        _removePhoto = false;
      });
    } catch (e) {
      _snack('تعذّر تجهيز الصورة: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final uid = context.read<UserAuthProvider>().user?.uid;
    if (uid != null) {
      try {
        if (_removePhoto) {
          await AvatarService.remove(uid);
        } else if (_newBytes != null) {
          await AvatarService.save(uid, _newBytes!);
        }
      } catch (_) {
        if (mounted) {
          setState(() => _busy = false);
          _snack('تعذّر حفظ الصورة. تأكد من نشر آخر firestore.rules والاتصال بالإنترنت.');
        }
        return;
      }
    }
    if (!mounted) return;
    final err = await context.read<UserAuthProvider>().updateProfile(
          displayName: _name.text,
          phone: normalizePhone(_phone.text),
          bio: _bio.text,
          academicYear: _year,
          department: _dept,
          photoUrl: _removePhoto ? null : (_newBytes != null ? 'avatar' : _photo),
          removePhoto: _removePhoto,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (err == null) {
      _snack('تم حفظ بياناتك');
      Navigator.pop(context);
    } else {
      _snack(err);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserAuthProvider>().user;
    if (user == null || user.role == UserRole.guest) {
      return Scaffold(
        appBar: AppBar(title: const Text('ملفي الشخصي')),
        body: const Center(child: Text('سجّل الدخول بحسابك لتعديل ملفك الشخصي.')),
      );
    }
    final shownPhoto = _removePhoto ? null : (_newBytes != null ? 'avatar' : _photo);
    return Scaffold(
      appBar: AppBar(title: const Text('ملفي الشخصي')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Center(
            child: Stack(children: [
              UserAvatar(name: _name.text, photoUrl: shownPhoto, uid: _removePhoto ? null : user.uid, bytes: _newBytes, radius: 54),
              PositionedDirectional(
                bottom: 0,
                end: 0,
                child: Material(
                  color: AppColors.primary,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _busy ? null : _pickPhoto,
                    child: const Padding(padding: EdgeInsets.all(9), child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20)),
                  ),
                ),
              ),
            ]),
          ),
          if (shownPhoto != null)
            Center(
              child: TextButton(
                onPressed: () => setState(() => _removePhoto = true),
                child: const Text('إزالة الصورة'),
              ),
            ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _name,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'الاسم', prefixIcon: Icon(Icons.person_outline)),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'أدخل اسمك' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
              labelText: 'رقم الهاتف',
              hintText: '01xxxxxxxxx',
              prefixIcon: Icon(Icons.phone_outlined),
              helperText: 'يظهر للمشرفين فقط',
            ),
            validator: (v) => isValidPhone(v ?? '') ? null : 'أدخل رقم هاتف مصري صحيحاً (11 رقماً)',
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _bio,
            maxLength: 150,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'نبذة عنك (اختياري)', prefixIcon: Icon(Icons.edit_note_rounded)),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _year,
            decoration: const InputDecoration(labelText: 'الفرقة الدراسية', prefixIcon: Icon(Icons.class_outlined)),
            items: [for (final y in AppConstants.academicYears) DropdownMenuItem(value: y, child: Text(y))],
            onChanged: (v) => setState(() => _year = v),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _dept,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'القسم', prefixIcon: Icon(Icons.apartment_rounded)),
            items: [for (final d in AppConstants.departments) DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis))],
            onChanged: (v) => setState(() => _dept = v),
          ),
          const SizedBox(height: 14),
          TextFormField(
            initialValue: user.email,
            enabled: false,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.email_outlined)),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_rounded),
            label: const Text('حفظ'),
          ),
          const SizedBox(height: 30),
        ]),
      ),
    );
  }
}
