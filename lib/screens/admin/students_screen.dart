import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/url_service.dart';
import '../../core/utils/phone.dart';
import '../../models/user_model.dart';
import '../../widgets/animations.dart';
import '../../widgets/user_avatar.dart';

/// Admin: registered students with their contact details.
class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('بيانات الطلاب')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'ابحث بالاسم أو الهاتف أو البريد', isDense: true),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('users').limit(1000).snapshots(),
            builder: (context, snap) {
              if (snap.hasError) return const Center(child: Text('تعذّر تحميل الطلاب.'));
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final users = snap.data!.docs.map(AppUser.fromFirestore).where((u) {
                if (_q.isEmpty) return true;
                return u.displayName.toLowerCase().contains(_q) ||
                    (u.phone ?? '').contains(_q) ||
                    u.email.toLowerCase().contains(_q);
              }).toList()
                ..sort((a, b) => a.displayName.compareTo(b.displayName));
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: users.length + 1,
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text('${users.length} طالب', style: TextStyle(color: Theme.of(context).hintColor)),
                    );
                  }
                  final u = users[i - 1];
                  final phone = u.phone ?? '';
                  return FadeSlideIn(
                    index: i,
                    child: Card(
                      child: ListTile(
                        leading: UserAvatar(name: u.displayName, photoUrl: u.photoUrl, radius: 22),
                        title: Text(u.displayName),
                        subtitle: Text([
                          if (u.academicYear != null) u.academicYear!,
                          if (u.department != null) u.department!,
                          phone.isEmpty ? 'لا يوجد رقم' : phone,
                        ].join(' • '), style: const TextStyle(fontSize: 12)),
                        trailing: phone.isEmpty
                            ? null
                            : Row(mainAxisSize: MainAxisSize.min, children: [
                                IconButton(
                                  tooltip: 'نسخ الرقم',
                                  icon: const Icon(Icons.copy_rounded, size: 20),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: phone));
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ الرقم')));
                                  },
                                ),
                                IconButton(
                                  tooltip: 'واتساب',
                                  icon: const Icon(Icons.chat_rounded, size: 20, color: Color(0xFF16A34A)),
                                  onPressed: () => UrlService.launchWebUrl(context, 'https://wa.me/${intlPhone(phone)}'),
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
