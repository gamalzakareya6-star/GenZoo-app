import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/camp_service.dart';
import '../../core/services/url_service.dart';
import '../../models/camp_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/daily_provider.dart';
import '../../core/data/motivation.dart';
import '../../widgets/animations.dart';
import 'camp_attach.dart';
import 'camp_chat.dart';
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
    final me = context.read<UserAuthProvider>().user;
    final name = me?.displayName ?? 'عضو';
    final photo = me?.photoUrl ?? '';
    return DefaultTabController(
      length: 4,
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
                } else if (v == 'delete' && await _confirm(context, 'حذف المعسكر؟', 'سيُحذف المعسكر بكل مهامه وملفاته ومحادثته.')) {
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
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.chat_bubble_rounded, size: 20), text: 'الدردشة'),
              Tab(icon: Icon(Icons.checklist_rounded, size: 20), text: 'المهام'),
              Tab(icon: Icon(Icons.folder_rounded, size: 20), text: 'الملفات'),
              Tab(icon: Icon(Icons.groups_rounded, size: 20), text: 'الأعضاء'),
            ],
          ),
        ),
        body: Column(children: [
          FadeSlideIn(offsetY: -12, child: _Header(camp: camp)),
          Expanded(
            child: TabBarView(children: [
              CampChat(camp: camp, uid: uid, name: name, photo: photo, manage: _manage),
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
    final now = DateTime.now();
    final total = camp.endAt.difference(camp.startAt).inHours.clamp(1, 100000);
    final passed = now.difference(camp.startAt).inHours.clamp(0, total);
    final daysLeft = camp.endAt.difference(now).inDays;
    final status = camp.hasEnded
        ? 'انتهى المعسكر'
        : now.isBefore(camp.startAt)
            ? 'يبدأ ${fmtDate(camp.startAt)}'
            : 'باقي $daysLeft يوم';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [AppColors.secondary, AppColors.primary],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.local_fire_department_rounded, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: Text(status, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          Text('${camp.memberIds.length} عضو', style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ]),
        const SizedBox(height: 10),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: passed / total),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: v,
              minHeight: 7,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: Text('${fmtDate(camp.startAt)} → ${fmtDate(camp.endAt)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
          if (camp.inviteCode.isNotEmpty)
            PressableScale(
              child: ActionChip(
                visualDensity: VisualDensity.compact,
                avatar: const Icon(Icons.copy_rounded, size: 14),
                label: Text('الكود ${camp.inviteCode}', style: const TextStyle(fontSize: 12)),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: camp.inviteCode));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ الكود')));
                },
              ),
            ),
        ]),
        if (camp.description.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(camp.description, style: const TextStyle(color: Colors.white, fontSize: 12.5)),
        ],
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
      backgroundColor: Colors.transparent,
      floatingActionButton: manage
          ? FloatingActionButton.extended(
              onPressed: () => _add(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('مهمة'),
            )
          : null,
      body: StreamBuilder<List<CampTask>>(
        stream: CampService.streamTasks(camp.id),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final tasks = snap.data!;
          if (tasks.isEmpty) return const Center(child: Text('لا توجد مهام بعد.'));
          final done = tasks.where((t) => t.isDone(uid)).length;
          return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 90), children: [
            Text('إنجازك: $done / ${tasks.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: done / tasks.length),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => LinearProgressIndicator(value: v, minHeight: 8, borderRadius: BorderRadius.circular(8)),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < tasks.length; i++)
              FadeSlideIn(
                index: i,
                child: Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: CheckboxListTile(
                    value: tasks[i].isDone(uid),
                    onChanged: (v) {
                      CampService.setDone(camp.id, tasks[i].id, uid, v == true);
                      if (v == true) {
                        final daily = context.read<DailyProvider>();
                        if (daily.studiedToday) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(Motivation.taskDoneMessage(i + DateTime.now().second))),
                          );
                        } else {
                          daily.markStudied(context);
                        }
                      }
                    },
                    title: Text(tasks[i].title,
                        style: TextStyle(decoration: tasks[i].isDone(uid) ? TextDecoration.lineThrough : null)),
                    subtitle: Text([
                      if (tasks[i].description.isNotEmpty) tasks[i].description,
                      if (tasks[i].deadline != null)
                        '${tasks[i].overdue && !tasks[i].isDone(uid) ? 'متأخرة • ' : ''}التسليم ${fmtDate(tasks[i].deadline!)}',
                      '${tasks[i].doneBy.length}/${camp.memberIds.length} أنجزوها',
                    ].join('\n')),
                    secondary: manage
                        ? IconButton(
                            icon: const Icon(Icons.delete_outline_rounded),
                            onPressed: () => CampService.deleteTask(camp.id, tasks[i].id),
                          )
                        : null,
                  ),
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

  Future<void> _addLink(BuildContext context) async {
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

  Future<void> _add(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: Icon(Icons.upload_file_rounded, color: AppColors.primary),
            title: const Text('رفع ملف من الجهاز'),
            onTap: () => Navigator.pop(ctx, 'device'),
          ),
          ListTile(
            leading: Icon(Icons.image_rounded, color: AppColors.secondary),
            title: const Text('رفع صورة'),
            onTap: () => Navigator.pop(ctx, 'image'),
          ),
          ListTile(
            leading: Icon(Icons.menu_book_rounded, color: AppColors.accent),
            title: const Text('اختيار من مواد التطبيق'),
            onTap: () => Navigator.pop(ctx, 'app'),
          ),
          ListTile(
            leading: const Icon(Icons.link_rounded),
            title: const Text('إضافة رابط'),
            onTap: () => Navigator.pop(ctx, 'link'),
          ),
        ]),
      ),
    );
    if (choice == null || !context.mounted) return;
    switch (choice) {
      case 'link':
        await _addLink(context);
      case 'app':
        final m = await pickAppMaterial(context);
        if (m != null) await CampService.addFile(camp.id, title: m.title, url: m.fileUrl, kind: 'app');
      default:
        final f = await pickAndUpload(context, image: choice == 'image');
        if (f != null) await CampService.addFile(camp.id, title: f.name, url: f.url, kind: 'upload');
    }
  }

  IconData _icon(CampFile f) => switch (f.kind) {
        'upload' => Icons.cloud_done_rounded,
        'app' => Icons.menu_book_rounded,
        _ => Icons.link_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('ملف'),
      ),
      body: StreamBuilder<List<CampFile>>(
        stream: CampService.streamFiles(camp.id),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final files = snap.data!;
          if (files.isEmpty) return const Center(child: Text('لا توجد ملفات بعد.'));
          return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 90), children: [
            for (var i = 0; i < files.length; i++)
              FadeSlideIn(
                index: i,
                child: Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(_icon(files[i]), color: AppColors.primary),
                    title: Text(files[i].title),
                    onTap: () => UrlService.launchWebUrl(context, files[i].url),
                    trailing: manage
                        ? IconButton(
                            icon: const Icon(Icons.delete_outline_rounded),
                            onPressed: () => CampService.deleteFile(camp.id, files[i].id),
                          )
                        : null,
                  ),
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
        final members = snap.data!;
        return ListView(padding: const EdgeInsets.all(16), children: [
          for (var i = 0; i < members.length; i++)
            FadeSlideIn(
              index: i,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.12),
                  child: Text(members[i].name.isEmpty ? '؟' : members[i].name.characters.first),
                ),
                title: Text(members[i].name),
                trailing: members[i].uid == camp.ownerId
                    ? const Chip(label: Text('المنشئ'))
                    : camp.adminIds.contains(members[i].uid)
                        ? const Chip(label: Text('مشرف'))
                        : null,
              ),
            ),
        ]);
      },
    );
  }
}
