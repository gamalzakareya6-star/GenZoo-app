import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/camp_service.dart';
import '../../core/services/url_service.dart';
import '../../models/camp_model.dart';
import '../../providers/auth_provider.dart';
import 'camps_screen.dart' show fmtDate;

class CampDetailScreen extends StatelessWidget {
  final String campId;
  const CampDetailScreen({super.key, required this.campId});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserAuthProvider>().user;
    final uid = user?.uid ?? '';
    return StreamBuilder<Camp?>(
      stream: CampService.streamCamp(campId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
        }
        final camp = snap.data;
        if (camp == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('هذا المعسكر لم يعد موجوداً.')));
        }
        final isMember = camp.memberIds.contains(uid);
        if (!isMember) return _Preview(camp: camp, uid: uid, name: user?.displayName ?? 'عضو');
        return _MemberView(camp: camp, uid: uid);
      },
    );
  }
}

class _Preview extends StatelessWidget {
  final Camp camp;
  final String uid;
  final String name;
  const _Preview({required this.camp, required this.uid, required this.name});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(camp.name)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(camp.description.isEmpty ? 'بدون وصف' : camp.description),
          const SizedBox(height: 12),
          Text('${camp.memberIds.length} عضو • ${fmtDate(camp.startAt)} → ${fmtDate(camp.endAt)}'),
          Text('المنشئ: ${camp.ownerName}'),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => CampService.joinPublic(campId: camp.id, uid: uid, userName: name),
              icon: const Icon(Icons.login_rounded),
              label: const Text('انضمام للمعسكر'),
            ),
          ),
        ]),
      ),
    );
  }
}

class _MemberView extends StatelessWidget {
  final Camp camp;
  final String uid;
  const _MemberView({required this.camp, required this.uid});

  bool get _manage => camp.canManage(uid);
  bool get _owner => camp.ownerId == uid;

  Future<bool> _confirm(BuildContext context, String title, String body) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(camp.name),
          actions: [
            PopupMenuButton<String>(
              onSelected: (v) async {
                final nav = Navigator.of(context);
                if (v == 'leave' && await _confirm(context, 'مغادرة المعسكر؟', 'يمكنك الانضمام مرة أخرى بالكود.')) {
                  await CampService.leave(campId: camp.id, uid: uid);
                  nav.pop();
                } else if (v == 'delete' && await _confirm(context, 'حذف المعسكر؟', 'سيُحذف المعسكر بكل مهامه وملفاته.')) {
                  await CampService.deleteCamp(camp);
                  nav.pop();
                }
              },
              itemBuilder: (_) => [
                if (!_owner) const PopupMenuItem(value: 'leave', child: Text('مغادرة')),
                if (_owner) const PopupMenuItem(value: 'delete', child: Text('حذف المعسكر')),
              ],
            ),
          ],
          bottom: const TabBar(tabs: [Tab(text: 'المهام'), Tab(text: 'الملفات'), Tab(text: 'الأعضاء')]),
        ),
        body: Column(children: [
          _Header(camp: camp),
          Expanded(
            child: TabBarView(children: [
              _Tasks(camp: camp, uid: uid, manage: _manage),
              _Files(camp: camp, manage: _manage),
              _Members(camp: camp),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Camp camp;
  const _Header({required this.camp});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      color: AppColors.secondary.withOpacity(0.08),
      child: Row(children: [
        Expanded(
          child: Text('${fmtDate(camp.startAt)} → ${fmtDate(camp.endAt)} • ${camp.memberIds.length} عضو',
              style: const TextStyle(fontSize: 12)),
        ),
        if (camp.inviteCode.isNotEmpty)
          ActionChip(
            avatar: const Icon(Icons.copy_rounded, size: 16),
            label: Text('الكود: ${camp.inviteCode}'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: camp.inviteCode));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ الكود')));
            },
          ),
      ]),
    );
  }
}

class _Tasks extends StatelessWidget {
  final Camp camp;
  final String uid;
  final bool manage;
  const _Tasks({required this.camp, required this.uid, required this.manage});

  Future<void> _add(BuildContext context) async {
    final title = TextEditingController();
    final desc = TextEditingController();
    DateTime? deadline;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('مهمة جديدة'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: 'العنوان')),
            TextField(controller: desc, maxLines: 2, decoration: const InputDecoration(labelText: 'تفاصيل (اختياري)')),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.event_rounded),
              label: Text(deadline == null ? 'موعد التسليم (اختياري)' : fmtDate(deadline!)),
              onPressed: () async {
                final d = await showDatePicker(
                  context: ctx,
                  initialDate: camp.startAt.isAfter(DateTime.now()) ? camp.startAt : DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                  lastDate: camp.endAt.add(const Duration(days: 1)),
                );
                if (d != null) setS(() => deadline = DateTime(d.year, d.month, d.day, 23, 59));
              },
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إضافة')),
          ],
        ),
      ),
    );
    if (ok == true && title.text.trim().isNotEmpty) {
      await CampService.addTask(camp.id, title: title.text, description: desc.text, deadline: deadline);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: manage
          ? FloatingActionButton.small(onPressed: () => _add(context), child: const Icon(Icons.add_rounded))
          : null,
      body: StreamBuilder<List<CampTask>>(
        stream: CampService.streamTasks(camp.id),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final tasks = snap.data!;
          if (tasks.isEmpty) return const Center(child: Text('لا توجد مهام بعد.'));
          final done = tasks.where((t) => t.isDone(uid)).length;
          return ListView(padding: const EdgeInsets.all(16), children: [
            Text('إنجازك: $done / ${tasks.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: done / tasks.length, minHeight: 8, borderRadius: BorderRadius.circular(8)),
            const SizedBox(height: 12),
            for (final t in tasks)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: CheckboxListTile(
                  value: t.isDone(uid),
                  onChanged: (v) => CampService.setDone(camp.id, t.id, uid, v == true),
                  title: Text(t.title, style: TextStyle(decoration: t.isDone(uid) ? TextDecoration.lineThrough : null)),
                  subtitle: Text([
                    if (t.description.isNotEmpty) t.description,
                    if (t.deadline != null) '${t.overdue && !t.isDone(uid) ? 'متأخرة • ' : ''}التسليم ${fmtDate(t.deadline!)}',
                    '${t.doneBy.length}/${camp.memberIds.length} أنجزوها',
                  ].join('\n')),
                  secondary: manage
                      ? IconButton(
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () => CampService.deleteTask(camp.id, t.id),
                        )
                      : null,
                ),
              ),
          ]);
        },
      ),
    );
  }
}

class _Files extends StatelessWidget {
  final Camp camp;
  final bool manage;
  const _Files({required this.camp, required this.manage});

  Future<void> _add(BuildContext context) async {
    final title = TextEditingController();
    final url = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة رابط ملف'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: title, decoration: const InputDecoration(labelText: 'الاسم')),
          TextField(
            controller: url,
            keyboardType: TextInputType.url,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(labelText: 'الرابط (Drive أو غيره)'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إضافة')),
        ],
      ),
    );
    final u = url.text.trim();
    if (ok == true && title.text.trim().isNotEmpty && u.startsWith('http')) {
      await CampService.addFile(camp.id, title: title.text, url: u);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: manage
          ? FloatingActionButton.small(onPressed: () => _add(context), child: const Icon(Icons.add_link_rounded))
          : null,
      body: StreamBuilder<List<CampFile>>(
        stream: CampService.streamFiles(camp.id),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final files = snap.data!;
          if (files.isEmpty) return const Center(child: Text('لا توجد ملفات بعد.'));
          return ListView(padding: const EdgeInsets.all(16), children: [
            for (final f in files)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.insert_drive_file_rounded, color: AppColors.primary),
                  title: Text(f.title),
                  onTap: () => UrlService.launchWebUrl(context, f.url),
                  trailing: manage
                      ? IconButton(
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () => CampService.deleteFile(camp.id, f.id),
                        )
                      : null,
                ),
              ),
          ]);
        },
      ),
    );
  }
}

class _Members extends StatelessWidget {
  final Camp camp;
  const _Members({required this.camp});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CampMember>>(
      stream: CampService.streamMembers(camp.id),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        return ListView(padding: const EdgeInsets.all(16), children: [
          for (final m in snap.data!)
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_rounded)),
              title: Text(m.name),
              trailing: m.uid == camp.ownerId
                  ? const Chip(label: Text('المنشئ'))
                  : camp.adminIds.contains(m.uid)
                      ? const Chip(label: Text('مشرف'))
                      : null,
            ),
        ]);
      },
    );
  }
}
