import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/camp_service.dart';
import '../../core/services/url_service.dart';
import '../../models/camp_model.dart';
import '../../providers/auth_provider.dart';
import '../../core/utils/drive_link.dart';
import '../../widgets/animations.dart';
import '../../widgets/news_images.dart' show openImageViewer;
import 'camp_attach.dart';
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
    final name = context.read<UserAuthProvider>().user?.displayName ?? 'عضو';
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
              _Chat(camp: camp, uid: uid, name: name, manage: _manage),
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
        gradient: const LinearGradient(
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

class _Chat extends StatefulWidget {
  final Camp camp;
  final String uid;
  final String name;
  final bool manage;
  const _Chat({required this.camp, required this.uid, required this.name, required this.manage});

  @override
  State<_Chat> createState() => _ChatState();
}

class _ChatState extends State<_Chat> with AutomaticKeepAliveClientMixin {
  final _ctrl = TextEditingController();
  bool _busy = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send({String imageUrl = '', String fileName = '', String fileUrl = ''}) async {
    final text = _ctrl.text;
    if (text.trim().isEmpty && imageUrl.isEmpty && fileUrl.isEmpty) return;
    _ctrl.clear();
    try {
      await CampService.sendMessage(widget.camp.id,
          uid: widget.uid, name: widget.name, text: text, imageUrl: imageUrl, fileName: fileName, fileUrl: fileUrl);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذّر إرسال الرسالة.')));
    }
  }

  Future<void> _attach() async {
    final choice = await showAttachMenu(context);
    if (choice == null || !mounted) return;
    setState(() => _busy = true);
    try {
      switch (choice) {
        case AttachChoice.image:
          final f = await pickAndUpload(context, image: true);
          if (f != null) await _send(imageUrl: f.url);
        case AttachChoice.device:
          final f = await pickAndUpload(context, image: false);
          if (f != null) await _send(fileName: f.name, fileUrl: f.url);
        case AttachChoice.app:
          final m = await pickAppMaterial(context);
          if (m != null) await _send(fileName: m.title, fileUrl: m.fileUrl);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(children: [
      Expanded(
        child: StreamBuilder<List<CampMessage>>(
          stream: CampService.streamMessages(widget.camp.id),
          builder: (context, snap) {
            if (snap.hasError) return const Center(child: Text('تعذّر تحميل المحادثة.'));
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final msgs = snap.data!;
            if (msgs.isEmpty) {
              return const Center(child: Text('ابدأ المحادثة مع زملائك 👋'));
            }
            return ListView.builder(
              reverse: true,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              itemCount: msgs.length,
              itemBuilder: (_, i) {
                final m = msgs[i];
                return FadeSlideIn(
                  key: ValueKey(m.id),
                  duration: const Duration(milliseconds: 280),
                  offsetY: 12,
                  child: _Bubble(
                    msg: m,
                    mine: m.uid == widget.uid,
                    onDelete: (m.uid == widget.uid || widget.manage)
                        ? () => CampService.deleteMessage(widget.camp.id, m.id)
                        : null,
                  ),
                );
              },
            );
          },
        ),
      ),
      if (_busy) const LinearProgressIndicator(minHeight: 2),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          child: Row(children: [
            IconButton(onPressed: _busy ? null : _attach, icon: const Icon(Icons.attach_file_rounded)),
            Expanded(
              child: TextField(
                controller: _ctrl,
                minLines: 1,
                maxLines: 4,
                maxLength: 1000,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'اكتب رسالة...',
                  isDense: true,
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 6),
            PressableScale(
              child: IconButton.filled(onPressed: _send, icon: const Icon(Icons.send_rounded)),
            ),
          ]),
        ),
      ),
    ]);
  }
}

class _Bubble extends StatelessWidget {
  final CampMessage msg;
  final bool mine;
  final VoidCallback? onDelete;
  const _Bubble({required this.msg, required this.mine, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = mine ? AppColors.primary : scheme.surfaceContainerHighest;
    final fg = mine ? Colors.white : scheme.onSurface;
    final t = msg.createdAt;
    final time = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return Align(
      alignment: mine ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
      child: GestureDetector(
        onLongPress: onDelete == null
            ? null
            : () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('حذف الرسالة؟'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
                    ],
                  ),
                );
                if (ok == true) onDelete!();
              },
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            if (!mine)
              Text(msg.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.secondary)),
            if (msg.imageUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: GestureDetector(
                  onTap: () => openImageViewer(context, [msg.imageUrl], 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      driveImageUrl(msg.imageUrl, width: 600),
                      height: 180,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, p) => p == null ? child : const SizedBox(height: 180, child: Center(child: CircularProgressIndicator())),
                      errorBuilder: (_, __, ___) => const SizedBox(height: 80, child: Center(child: Icon(Icons.broken_image_rounded))),
                    ),
                  ),
                ),
              ),
            if (msg.fileUrl.isNotEmpty)
              InkWell(
                onTap: () => UrlService.launchWebUrl(context, msg.fileUrl),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.insert_drive_file_rounded, color: fg, size: 20),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(msg.fileName.isEmpty ? 'ملف' : msg.fileName,
                          style: TextStyle(color: fg, decoration: TextDecoration.underline)),
                    ),
                  ]),
                ),
              ),
            if (msg.text.isNotEmpty) Text(msg.text, style: TextStyle(color: fg, height: 1.35)),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Text(time, style: TextStyle(color: fg.withOpacity(0.6), fontSize: 10)),
            ),
          ]),
        ),
      ),
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
                    onChanged: (v) => CampService.setDone(camp.id, tasks[i].id, uid, v == true),
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
            leading: const Icon(Icons.upload_file_rounded, color: AppColors.primary),
            title: const Text('رفع ملف من الجهاز'),
            onTap: () => Navigator.pop(ctx, 'device'),
          ),
          ListTile(
            leading: const Icon(Icons.image_rounded, color: AppColors.secondary),
            title: const Text('رفع صورة'),
            onTap: () => Navigator.pop(ctx, 'image'),
          ),
          ListTile(
            leading: const Icon(Icons.menu_book_rounded, color: AppColors.accent),
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
