import 'package:flutter/material.dart';
import 'user_avatar.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/services/comments_service.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';

/// The comments of one news post, with a box to write a new one.
class CommentsSection extends StatefulWidget {
  final String newsId;
  const CommentsSection({super.key, required this.newsId});

  @override
  State<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<CommentsSection> {
  final _controller = TextEditingController();
  bool _sending = false;
  DateTime? _lastSent;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send(AppUser user) async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    final last = _lastSent;
    if (last != null && DateTime.now().difference(last).inSeconds < 5) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('انتظر قليلاً قبل إرسال تعليق آخر.')));
      return;
    }
    setState(() => _sending = true);
    try {
      await CommentsService.add(newsId: widget.newsId, uid: user.uid, name: user.displayName, text: text, photo: user.photoUrl ?? '');
      _controller.clear();
      _lastSent = DateTime.now();
      if (mounted) FocusScope.of(context).unfocus();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذّر إرسال التعليق. حاول مرة أخرى.')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<UserAuthProvider>();
    final user = auth.user;
    final canWrite = user != null && user.role != UserRole.guest;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 28),
        const Row(children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 18),
          SizedBox(width: 6),
          Text('التعليقات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ]),
        const SizedBox(height: 10),
        if (canWrite)
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  maxLength: CommentsService.maxLength,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(hintText: 'اكتب تعليقاً...', counterText: ''),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _sending ? null : () => _send(user),
                icon: _sending
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded),
              ),
            ],
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('سجّل الدخول بحسابك لتتمكن من التعليق.', style: TextStyle(fontSize: 12.5)),
          ),
        const SizedBox(height: 12),
        StreamBuilder<List<NewsComment>>(
          stream: CommentsService.stream(widget.newsId),
          builder: (context, snap) {
            if (snap.hasError) {
              return const Text('تعذّر تحميل التعليقات.', style: TextStyle(fontSize: 12));
            }
            if (!snap.hasData) {
              return const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
            }
            final list = snap.data!;
            if (list.isEmpty) {
              return Text('لا توجد تعليقات بعد. كن أول من يعلّق!', style: TextStyle(fontSize: 12.5, color: theme.hintColor));
            }
            return Column(
              children: [
                for (final c in list)
                  _CommentTile(
                    comment: c,
                    canDelete: auth.isAdmin || (user != null && user.uid == c.uid),
                    onDelete: () => CommentsService.delete(widget.newsId, c.id),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  final NewsComment comment;
  final bool canDelete;
  final VoidCallback onDelete;
  const _CommentTile({required this.comment, required this.canDelete, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = comment.name.trim().isEmpty ? '؟' : comment.name.trim().characters.first;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.35),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(name: comment.name, photoUrl: comment.photo, uid: comment.uid, radius: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(child: Text(comment.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
                  const SizedBox(width: 8),
                  Text(DateFormat('d MMM • h:mm a').format(comment.createdAt), style: TextStyle(fontSize: 10.5, color: theme.hintColor)),
                ]),
                const SizedBox(height: 3),
                SelectableText(comment.text, style: const TextStyle(fontSize: 13.5, height: 1.4)),
              ],
            ),
          ),
          if (canDelete)
            InkWell(
              onTap: onDelete,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
              ),
            ),
        ],
      ),
    );
  }
}
