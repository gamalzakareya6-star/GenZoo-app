import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/animations.dart';
import '../../widgets/user_avatar.dart';

/// Super-admin only: appoint/dismiss admins, or hand over the super-admin role.
class ManageAdminsScreen extends StatefulWidget {
  const ManageAdminsScreen({super.key});

  @override
  State<ManageAdminsScreen> createState() => _ManageAdminsScreenState();
}

class _ManageAdminsScreenState extends State<ManageAdminsScreen> {
  String _q = '';
  String? _busyUid;

  Color _roleColor(UserRole r) => switch (r) {
        UserRole.superAdmin => const Color(0xFFB91C1C),
        UserRole.admin => AppColors.primary,
        _ => Colors.grey,
      };

  String _roleLabel(UserRole r) => switch (r) {
        UserRole.superAdmin => 'مسؤول عام',
        UserRole.admin => 'مسؤول',
        UserRole.guest => 'زائر',
        UserRole.student => 'طالب',
      };

  Future<void> _change(AppUser target, UserRole role, String confirmText) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد'),
        content: Text(confirmText),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تأكيد')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busyUid = target.uid);
    final err = await context.read<UserAuthProvider>().setUserRole(target.uid, role);
    if (!mounted) return;
    setState(() => _busyUid = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(err ?? 'تم تحديث صلاحية ${target.displayName}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<UserAuthProvider>().user;
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة المسؤولين')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'ابحث بالاسم أو البريد',
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('users').limit(1000).snapshots(),
            builder: (context, snap) {
              if (snap.hasError) return const Center(child: Text('تعذّر تحميل المستخدمين.'));
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final users = snap.data!.docs.map(AppUser.fromFirestore).where((u) {
                if (_q.isEmpty) return true;
                return u.displayName.toLowerCase().contains(_q) || u.email.toLowerCase().contains(_q);
              }).toList()
                ..sort((a, b) {
                  int rank(UserRole r) => r == UserRole.superAdmin ? 0 : (r == UserRole.admin ? 1 : 2);
                  final c = rank(a.role).compareTo(rank(b.role));
                  return c != 0 ? c : a.displayName.compareTo(b.displayName);
                });
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: users.length + 1,
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        '${users.where((u) => u.isAdmin).length} مسؤول من أصل ${users.length}',
                        style: TextStyle(color: Theme.of(context).hintColor),
                      ),
                    );
                  }
                  final u = users[i - 1];
                  final isMe = u.uid == me?.uid;
                  final busy = _busyUid == u.uid;
                  return FadeSlideIn(
                    index: i,
                    child: Card(
                      child: ListTile(
                        leading: UserAvatar(name: u.displayName, photoUrl: u.photoUrl, uid: u.uid, radius: 22),
                        title: Text(u.displayName, overflow: TextOverflow.ellipsis),
                        subtitle: Text(u.email, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                        trailing: busy
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : Row(mainAxisSize: MainAxisSize.min, children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  margin: const EdgeInsets.only(left: 4),
                                  decoration: BoxDecoration(
                                    color: _roleColor(u.role).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(_roleLabel(u.role),
                                      style: TextStyle(color: _roleColor(u.role), fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                                if (!isMe)
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert_rounded),
                                    onSelected: (v) {
                                      switch (v) {
                                        case 'make_admin':
                                          _change(u, UserRole.admin, 'ترقية "${u.displayName}" إلى مسؤول؟ سيتمكن من إدارة المحتوى والموافقة على الملفات.');
                                          break;
                                        case 'make_super':
                                          _change(u, UserRole.superAdmin, 'ترقية "${u.displayName}" إلى مسؤول عام؟ سيتمكن من تعيين وعزل المسؤولين أيضاً.');
                                          break;
                                        case 'to_student':
                                          _change(u, UserRole.student, 'عزل "${u.displayName}" من الإشراف وإعادته طالباً عادياً؟');
                                          break;
                                        case 'to_admin':
                                          _change(u, UserRole.admin, 'تنزيل "${u.displayName}" من مسؤول عام إلى مسؤول عادي؟');
                                          break;
                                      }
                                    },
                                    itemBuilder: (ctx) => [
                                      if (u.role == UserRole.student)
                                        const PopupMenuItem(value: 'make_admin', child: Text('ترقية إلى مسؤول')),
                                      if (u.role == UserRole.admin) ...[
                                        const PopupMenuItem(value: 'make_super', child: Text('ترقية إلى مسؤول عام')),
                                        const PopupMenuItem(value: 'to_student', child: Text('عزل من الإشراف')),
                                      ],
                                      if (u.role == UserRole.superAdmin)
                                        const PopupMenuItem(value: 'to_admin', child: Text('تنزيل إلى مسؤول عادي')),
                                    ],
                                  ),
                              ]),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}
