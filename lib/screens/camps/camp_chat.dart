import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/camp_service.dart';
import '../../core/services/drive_upload_service.dart';
import '../../core/services/url_service.dart';
import '../../core/utils/drive_link.dart';
import '../../models/camp_model.dart';
import '../../widgets/animations.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/news_images.dart' show openImageViewer;
import 'camp_attach.dart';

const _reactionEmojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

String _two(int n) => n.toString().padLeft(2, '0');
String _hm(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';
String _dur(int secs) => '${secs ~/ 60}:${_two(secs % 60)}';

String _dayLabel(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'اليوم';
  if (diff == 1) return 'أمس';
  return '${d.year}/${_two(d.month)}/${_two(d.day)}';
}

/// Camp chat with the usual messenger features: replies, reactions, edit,
/// delete for everyone, read receipts, typing indicator, voice notes,
/// images and files.
class CampChat extends StatefulWidget {
  final Camp camp;
  final String uid;
  final String name;
  final String photo;
  final bool manage;
  const CampChat({super.key, required this.camp, required this.uid, required this.name, this.photo = '', required this.manage});

  @override
  State<CampChat> createState() => _CampChatState();
}

class _CampChatState extends State<CampChat> with AutomaticKeepAliveClientMixin {
  final _ctrl = TextEditingController();
  final _recorder = AudioRecorder();
  bool _busy = false;
  bool _hasText = false;

  Map<String, dynamic>? _replyTo;
  CampMessage? _editing;

  bool _recording = false;
  int _recSecs = 0;
  Timer? _recTimer;

  DateTime _lastTypingWrite = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _typingStop;
  Timer? _ticker; // re-evaluates the "typing..." label
  final Set<String> _seenRequested = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onText);
    _ticker = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _recTimer?.cancel();
    _typingStop?.cancel();
    _ticker?.cancel();
    _recorder.dispose();
    CampService.setTyping(widget.camp.id, widget.uid, widget.name, false).catchError((_) {});
    super.dispose();
  }

  void _onText() {
    final has = _ctrl.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
    if (!has) return;
    final now = DateTime.now();
    if (now.difference(_lastTypingWrite) > const Duration(seconds: 3)) {
      _lastTypingWrite = now;
      CampService.setTyping(widget.camp.id, widget.uid, widget.name, true).catchError((_) {});
    }
    _typingStop?.cancel();
    _typingStop = Timer(const Duration(seconds: 4), () {
      _lastTypingWrite = DateTime.fromMillisecondsSinceEpoch(0);
      CampService.setTyping(widget.camp.id, widget.uid, widget.name, false).catchError((_) {});
    });
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  String _previewOf(CampMessage m) {
    if (m.deleted) return 'رسالة محذوفة';
    if (m.text.isNotEmpty) return m.text.length > 80 ? '${m.text.substring(0, 80)}…' : m.text;
    if (m.audioUrl.isNotEmpty) return '🎤 رسالة صوتية';
    if (m.imageUrl.isNotEmpty) return '📷 صورة';
    if (m.fileUrl.isNotEmpty) return '📎 ${m.fileName.isEmpty ? 'ملف' : m.fileName}';
    return '';
  }

  Future<void> _send({
    String imageUrl = '',
    String fileName = '',
    String fileUrl = '',
    String audioUrl = '',
    int audioSecs = 0,
  }) async {
    final text = _ctrl.text;
    final media = imageUrl.isNotEmpty || fileUrl.isNotEmpty || audioUrl.isNotEmpty;
    if (text.trim().isEmpty && !media) return;

    // Editing an existing message.
    if (_editing != null) {
      final id = _editing!.id;
      setState(() => _editing = null);
      _ctrl.clear();
      try {
        await CampService.editMessage(widget.camp.id, id, text);
      } catch (_) {
        _snack('تعذّر تعديل الرسالة.');
      }
      return;
    }

    final reply = _replyTo;
    _ctrl.clear();
    setState(() => _replyTo = null);
    _typingStop?.cancel();
    CampService.setTyping(widget.camp.id, widget.uid, widget.name, false).catchError((_) {});
    try {
      await CampService.sendMessage(
        widget.camp.id,
        uid: widget.uid,
        name: widget.name,
        text: text,
        imageUrl: imageUrl,
        fileName: fileName,
        fileUrl: fileUrl,
        audioUrl: audioUrl,
        audioSecs: audioSecs,
        photo: widget.photo,
        replyTo: reply,
      );
    } catch (_) {
      _snack('تعذّر إرسال الرسالة.');
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

  // ---- voice notes ----

  Future<void> _startRecording() async {
    try {
      if (!await _recorder.hasPermission()) {
        _snack('اسمح للتطبيق باستخدام الميكروفون لتسجيل رسالة صوتية.');
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/vn_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
      _recSecs = 0;
      _recTimer?.cancel();
      _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _recSecs++);
        if (_recSecs >= 300) _finishRecording(send: true); // 5 minutes max
      });
      setState(() => _recording = true);
    } catch (_) {
      _snack('تعذّر بدء التسجيل.');
    }
  }

  Future<void> _finishRecording({required bool send}) async {
    _recTimer?.cancel();
    final secs = _recSecs;
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _recording = false);
    if (!send || path == null || secs < 1) return;
    setState(() => _busy = true);
    try {
      final f = await DriveUploadService.upload(path, displayName: 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a');
      await _send(audioUrl: f.url, audioSecs: secs);
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---- message menu ----

  Future<void> _openMenu(CampMessage m) async {
    if (m.deleted) return;
    final mine = m.uid == widget.uid;
    final myReaction = m.reactions[widget.uid];
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              for (final e in _reactionEmojis)
                InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => Navigator.pop(ctx, 'react:$e'),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: myReaction == e ? AppColors.primary.withOpacity(0.15) : null,
                    ),
                    child: Text(e, style: const TextStyle(fontSize: 26)),
                  ),
                ),
            ]),
          ),
          const Divider(),
          ListTile(leading: const Icon(Icons.reply_rounded), title: const Text('رد'), onTap: () => Navigator.pop(ctx, 'reply')),
          if (m.text.isNotEmpty)
            ListTile(leading: const Icon(Icons.copy_rounded), title: const Text('نسخ'), onTap: () => Navigator.pop(ctx, 'copy')),
          if (mine && m.text.isNotEmpty && m.audioUrl.isEmpty)
            ListTile(leading: const Icon(Icons.edit_rounded), title: const Text('تعديل'), onTap: () => Navigator.pop(ctx, 'edit')),
          if (mine)
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: Text('شاهدها ${(m.seenBy.length - 1).clamp(0, 9999)} من ${widget.camp.memberIds.length - 1}'),
              onTap: () => Navigator.pop(ctx, 'info'),
            ),
          if (mine || widget.manage)
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              title: const Text('حذف للجميع', style: TextStyle(color: AppColors.error)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
        ]),
      ),
    );
    if (action == null || !mounted) return;
    if (action.startsWith('react:')) {
      CampService.toggleReaction(widget.camp.id, m.id, widget.uid, action.substring(6), myReaction).catchError((_) {});
    } else if (action == 'reply') {
      setState(() {
        _editing = null;
        _replyTo = {'id': m.id, 'name': m.name, 'text': _previewOf(m)};
      });
    } else if (action == 'copy') {
      Clipboard.setData(ClipboardData(text: m.text));
      _snack('تم نسخ الرسالة');
    } else if (action == 'edit') {
      setState(() {
        _replyTo = null;
        _editing = m;
        _ctrl.text = m.text;
        _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
      });
    } else if (action == 'delete') {
      try {
        await CampService.deleteForEveryone(widget.camp.id, m.id);
      } catch (_) {
        // A camp admin who is not the sender can only remove the document.
        await CampService.deleteMessage(widget.camp.id, m.id).catchError((_) {});
      }
    }
  }

  void _markSeen(List<CampMessage> msgs) {
    final todo = msgs
        .where((m) => m.uid != widget.uid && !m.seenBy.contains(widget.uid) && !_seenRequested.contains(m.id))
        .take(30)
        .map((m) => m.id)
        .toList();
    if (todo.isEmpty) return;
    _seenRequested.addAll(todo);
    CampService.markSeen(widget.camp.id, todo, widget.uid);
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
            if (msgs.isEmpty) return const Center(child: Text('ابدأ المحادثة مع زملائك 👋'));
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _markSeen(msgs);
            });
            return ListView.builder(
              reverse: true,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              itemCount: msgs.length,
              itemBuilder: (_, i) {
                final m = msgs[i];
                final newDay = i == msgs.length - 1 ||
                    _dayLabel(msgs[i + 1].createdAt) != _dayLabel(m.createdAt);
                return Column(children: [
                  if (newDay) _DaySeparator(label: _dayLabel(m.createdAt)),
                  FadeSlideIn(
                    key: ValueKey(m.id),
                    duration: const Duration(milliseconds: 260),
                    offsetY: 10,
                    child: Dismissible(
                      key: ValueKey('swipe_${m.id}'),
                      confirmDismiss: (_) async {
                        if (!m.deleted) {
                          setState(() {
                            _editing = null;
                            _replyTo = {'id': m.id, 'name': m.name, 'text': _previewOf(m)};
                          });
                        }
                        return false;
                      },
                      child: _Bubble(
                        msg: m,
                        mine: m.uid == widget.uid,
                        members: widget.camp.memberIds.length,
                        onLongPress: () => _openMenu(m),
                        onReact: (e) => CampService
                            .toggleReaction(widget.camp.id, m.id, widget.uid, e, m.reactions[widget.uid])
                            .catchError((_) {}),
                      ),
                    ),
                  ),
                ]);
              },
            );
          },
        ),
      ),
      _typingLabel(),
      if (_busy) const LinearProgressIndicator(minHeight: 2),
      if (_replyTo != null || _editing != null) _contextBar(),
      SafeArea(top: false, child: _recording ? _recordingBar() : _inputBar()),
    ]);
  }

  Widget _typingLabel() {
    return StreamBuilder<List<CampTyping>>(
      stream: CampService.streamTyping(widget.camp.id),
      builder: (context, snap) {
        final now = DateTime.now();
        final names = (snap.data ?? const <CampTyping>[])
            .where((t) => t.uid != widget.uid && now.difference(t.at).inSeconds < 7)
            .map((t) => t.name)
            .toList();
        return AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: names.isEmpty
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      names.length == 1 ? '${names.first} يكتب الآن...' : '${names.length} أشخاص يكتبون الآن...',
                      style: TextStyle(fontSize: 12, color: AppColors.secondary),
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _contextBar() {
    final editing = _editing != null;
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: BorderDirectional(start: BorderSide(color: AppColors.secondary, width: 4)),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(editing ? 'تعديل الرسالة' : 'رد على ${_replyTo!['name']}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.secondary)),
            Text(editing ? _editing!.text : '${_replyTo!['text']}',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
          ]),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded, size: 20),
          onPressed: () {
            if (editing) _ctrl.clear();
            setState(() {
              _replyTo = null;
              _editing = null;
            });
          },
        ),
      ]),
    );
  }

  Widget _inputBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Row(children: [
        IconButton(onPressed: _busy || _editing != null ? null : _attach, icon: const Icon(Icons.attach_file_rounded)),
        Expanded(
          child: TextField(
            controller: _ctrl,
            minLines: 1,
            maxLines: 5,
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
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
          child: (_hasText || _editing != null)
              ? IconButton.filled(key: const ValueKey('send'), onPressed: _send, icon: Icon(_editing != null ? Icons.check_rounded : Icons.send_rounded))
              : IconButton.filled(
                  key: const ValueKey('mic'),
                  onPressed: _busy ? null : _startRecording,
                  icon: const Icon(Icons.mic_rounded),
                ),
        ),
      ]),
    );
  }

  Widget _recordingBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Row(children: [
        IconButton(
          onPressed: () => _finishRecording(send: false),
          icon: const Icon(Icons.delete_rounded, color: AppColors.error),
        ),
        const _BlinkingDot(),
        const SizedBox(width: 8),
        Text(_dur(_recSecs), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const Expanded(child: Center(child: Text('جارٍ التسجيل...', style: TextStyle(fontSize: 12)))),
        IconButton.filled(onPressed: () => _finishRecording(send: true), icon: const Icon(Icons.send_rounded)),
      ]),
    );
  }
}

class _BlinkingDot extends StatefulWidget {
  const _BlinkingDot();
  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _c,
        child: const Icon(Icons.fiber_manual_record_rounded, color: AppColors.error, size: 14),
      );
}

class _DaySeparator extends StatelessWidget {
  final String label;
  const _DaySeparator({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label, style: const TextStyle(fontSize: 11.5)),
        ),
      );
}

class _Bubble extends StatelessWidget {
  final CampMessage msg;
  final bool mine;
  final int members;
  final VoidCallback onLongPress;
  final void Function(String emoji) onReact;
  const _Bubble({required this.msg, required this.mine, required this.members, required this.onLongPress, required this.onReact});

  Widget _ticks(Color fg) {
    final all = msg.seenBy.length >= members && members > 1;
    final some = msg.seenBy.length > 1;
    return Icon(
      some ? Icons.done_all_rounded : Icons.done_rounded,
      size: 15,
      color: all ? const Color(0xFF53BDEB) : fg.withOpacity(0.6),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = mine ? AppColors.primary : scheme.surfaceContainerHighest;
    final fg = mine ? Colors.white : scheme.onSurface;

    final grouped = <String, int>{};
    for (final e in msg.reactions.values) {
      grouped[e] = (grouped[e] ?? 0) + 1;
    }

    final content = msg.deleted
        ? Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.block_rounded, size: 15, color: fg.withOpacity(0.6)),
            const SizedBox(width: 6),
            Text('تم حذف هذه الرسالة', style: TextStyle(color: fg.withOpacity(0.7), fontStyle: FontStyle.italic)),
          ])
        : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            if (!mine)
              Text(msg.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.secondaryLight)),
            if (msg.replyTo != null) _Quote(reply: msg.replyTo!, fg: fg, mine: mine),
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
                      loadingBuilder: (_, child, p) =>
                          p == null ? child : const SizedBox(height: 180, child: Center(child: CircularProgressIndicator())),
                      errorBuilder: (_, __, ___) => const SizedBox(height: 80, child: Center(child: Icon(Icons.broken_image_rounded))),
                    ),
                  ),
                ),
              ),
            if (msg.audioUrl.isNotEmpty) _VoicePlayer(url: msg.audioUrl, secs: msg.audioSecs, fg: fg),
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
          ]);

    final bubble = GestureDetector(
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: mine ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              constraints: BoxConstraints(maxWidth: (MediaQuery.of(context).size.width * 0.78).clamp(0.0, 460.0)),
              margin: EdgeInsets.only(top: 3, bottom: grouped.isEmpty ? 3 : 0),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                content,
                const SizedBox(height: 2),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  if (msg.edited && !msg.deleted)
                    Text('معدّلة  ', style: TextStyle(color: fg.withOpacity(0.6), fontSize: 10)),
                  Text(_hm(msg.createdAt), style: TextStyle(color: fg.withOpacity(0.6), fontSize: 10)),
                  if (mine && !msg.deleted) ...[const SizedBox(width: 3), _ticks(fg)],
                ]),
              ]),
            ),
            if (grouped.isNotEmpty)
              Transform.translate(
                offset: const Offset(0, -4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    for (final e in grouped.entries)
                      GestureDetector(
                        onTap: () => onReact(e.key),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Text(e.value > 1 ? '${e.key}${e.value}' : e.key, style: const TextStyle(fontSize: 13)),
                        ),
                      ),
                  ]),
                ),
              ),
          ],
        ),
      );

    return Align(
      alignment: mine ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
      child: mine
          ? bubble
          : Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(bottom: 4, end: 6),
                  child: UserAvatar(name: msg.name, photoUrl: msg.photo, radius: 14),
                ),
                Flexible(child: bubble),
              ],
            ),
    );
  }
}

class _Quote extends StatelessWidget {
  final Map<String, dynamic> reply;
  final Color fg;
  final bool mine;
  const _Quote({required this.reply, required this.fg, required this.mine});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      decoration: BoxDecoration(
        color: fg.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: BorderDirectional(start: BorderSide(color: AppColors.secondaryLight, width: 3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${reply['name'] ?? ''}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppColors.secondaryLight)),
        Text('${reply['text'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: fg.withOpacity(0.85), fontSize: 12)),
      ]),
    );
  }
}

class _VoicePlayer extends StatefulWidget {
  final String url;
  final int secs;
  final Color fg;
  const _VoicePlayer({required this.url, required this.secs, required this.fg});

  @override
  State<_VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends State<_VoicePlayer> {
  AudioPlayer? _player;
  bool _playing = false;
  bool _loading = false;
  Duration _pos = Duration.zero;
  Duration _total = Duration.zero;
  final List<StreamSubscription> _subs = [];

  @override
  void initState() {
    super.initState();
    _total = Duration(seconds: widget.secs);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player?.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    try {
      if (_player == null) {
        final p = AudioPlayer();
        _player = p;
        _subs
          ..add(p.onPositionChanged.listen((d) {
            if (mounted) setState(() => _pos = d);
          }))
          ..add(p.onDurationChanged.listen((d) {
            if (mounted && d > Duration.zero) setState(() => _total = d);
          }))
          ..add(p.onPlayerComplete.listen((_) {
            if (mounted) setState(() {
              _playing = false;
              _pos = Duration.zero;
            });
          }));
        setState(() => _loading = true);
        await p.play(UrlSource(directDownloadUrl(widget.url)));
        if (mounted) setState(() {
          _loading = false;
          _playing = true;
        });
        return;
      }
      if (_playing) {
        await _player!.pause();
        setState(() => _playing = false);
      } else {
        await _player!.resume();
        setState(() => _playing = true);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _playing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذّر تشغيل الرسالة الصوتية.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = _total.inMilliseconds;
    final value = totalMs <= 0 ? 0.0 : (_pos.inMilliseconds / totalMs).clamp(0.0, 1.0);
    return SizedBox(
      width: 210,
      child: Row(children: [
        _loading
            ? const Padding(padding: EdgeInsets.all(10), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
            : IconButton(
                onPressed: _toggle,
                icon: Icon(_playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, color: widget.fg, size: 34),
              ),
        Expanded(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            LinearProgressIndicator(
              value: value,
              minHeight: 3,
              backgroundColor: widget.fg.withOpacity(0.25),
              valueColor: AlwaysStoppedAnimation(widget.fg),
            ),
            const SizedBox(height: 4),
            Text(_dur(_playing || _pos > Duration.zero ? _pos.inSeconds : _total.inSeconds),
                style: TextStyle(color: widget.fg.withOpacity(0.8), fontSize: 11)),
          ]),
        ),
      ]),
    );
  }
}
