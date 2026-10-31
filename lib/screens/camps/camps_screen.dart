import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/camp_service.dart';
import '../../models/camp_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/animations.dart';
import 'camp_detail_screen.dart';

String fmtDate(DateTime d) => '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

/// معسكرات المذاكرة: my camps / public camps / join with a code.
class CampsScreen extends StatelessWidget {
  const CampsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserAuthProvider>().user;
    final signedIn = user != null && user.role != UserRole.guest;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('معسكرات المذاكرة'),
          bottom: const TabBar(tabs: [Tab(text: 'معسكراتي'), Tab(text: 'عامة'), Tab(text: 'انضم بكود')]),
        ),
        floatingActionButton: signedIn
            ? FloatingActionButton.extended(
                onPressed: () => _createCamp(context, user),
                icon: const Icon(Icons.add_rounded),
                label: const Text('معسكر جديد'),
              )
            : null,
        body: !signedIn
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('سجّل الدخول بحسابك لاستخدام معسكرات المذاكرة.', textAlign: TextAlign.center),
                ),
              )
            : TabBarView(children: [
                _CampList(stream: CampService.streamMine(user.uid), empty: 'لم تنضم لأي معسكر بعد.'),
                _CampList(stream: CampService.streamPublic(), empty: 'لا توجد معسكرات عامة الآن.', user: user),
                _JoinByCode(user: user),
              ]),
      ),
    );
  }

  Future<void> _createCamp(BuildContext context, AppUser user) async {
    final id = await showDialog<String>(context: context, builder: (_) => _CreateCampDialog(user: user));
    if (id != null && context.mounted) {
      Navigator.push(context, AppRoute.fadeSlide(CampDetailScreen(campId: id)));
    }
  }
}

class _CampList extends StatelessWidget {
  final Stream<List<Camp>> stream;
  final String empty;
  final AppUser? user;
  const _CampList({required this.stream, required this.empty, this.user});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Camp>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) return const Center(child: Text('تعذّر تحميل المعسكرات.'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final camps = snap.data!.where((c) => !c.hasEnded || c.memberIds.contains(user?.uid)).toList();
        if (camps.isEmpty) return Center(child: Text(empty));
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          itemCount: camps.length,
          itemBuilder: (_, i) => FadeSlideIn(index: i, child: _CampCard(camp: camps[i])),
        );
      },
    );
  }
}

class _CampCard extends StatelessWidget {
  final Camp camp;
  const _CampCard({required this.camp});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () => Navigator.push(context, AppRoute.fadeSlide(CampDetailScreen(campId: camp.id))),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.secondary.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
          child: Icon(camp.isPublic ? Icons.groups_rounded : Icons.lock_rounded, color: AppColors.secondary),
        ),
        title: Text(camp.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${camp.memberIds.length} عضو • ${fmtDate(camp.startAt)} → ${fmtDate(camp.endAt)}',
            style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_left_rounded),
      ),
    );
  }
}

class _JoinByCode extends StatefulWidget {
  final AppUser user;
  const _JoinByCode({required this.user});

  @override
  State<_JoinByCode> createState() => _JoinByCodeState();
}

class _JoinByCodeState extends State<_JoinByCode> {
  final _ctrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (_ctrl.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final id = await CampService.joinByCode(
          uid: widget.user.uid, userName: widget.user.displayName, code: _ctrl.text);
      if (!mounted) return;
      Navigator.push(context, AppRoute.fadeSlide(CampDetailScreen(campId: id)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is CampException ? e.message : 'تعذّر الانضمام.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.vpn_key_rounded, size: 48, color: AppColors.secondary),
          const SizedBox(height: 16),
          const Text('أدخل كود الدعوة الذي أرسله لك صاحب المعسكر', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            style: const TextStyle(fontSize: 24, letterSpacing: 6, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(border: OutlineInputBorder(), counterText: ''),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _join,
              child: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('انضمام'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateCampDialog extends StatefulWidget {
  final AppUser user;
  const _CreateCampDialog({required this.user});

  @override
  State<_CreateCampDialog> createState() => _CreateCampDialogState();
}

class _CreateCampDialogState extends State<_CreateCampDialog> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  bool _public = false;
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now().add(const Duration(days: 7));
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pick(bool start) async {
    final d = await showDatePicker(
      context: context,
      initialDate: start ? _start : _end,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d == null) return;
    setState(() {
      if (start) {
        _start = d;
        if (_end.isBefore(_start)) _end = _start.add(const Duration(days: 1));
      } else {
        _end = d.isBefore(_start) ? _start : d;
      }
    });
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final id = await CampService.create(
        uid: widget.user.uid,
        userName: widget.user.displayName,
        name: _name.text,
        description: _desc.text,
        isPublic: _public,
        startAt: _start,
        endAt: DateTime(_end.year, _end.month, _end.day, 23, 59),
      );
      if (mounted) Navigator.pop(context, id);
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذّر إنشاء المعسكر.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('معسكر جديد'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: _name, maxLength: 80, decoration: const InputDecoration(labelText: 'اسم المعسكر')),
          TextField(controller: _desc, maxLines: 2, decoration: const InputDecoration(labelText: 'وصف (اختياري)')),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _public,
            onChanged: (v) => setState(() => _public = v),
            title: const Text('معسكر عام'),
            subtitle: Text(_public ? 'يظهر للجميع ويمكنهم الانضمام' : 'الانضمام بكود الدعوة فقط'),
          ),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => _pick(true), child: Text('من ${fmtDate(_start)}'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton(onPressed: () => _pick(false), child: Text('إلى ${fmtDate(_end)}'))),
          ]),
          const SizedBox(height: 6),
          const Text('يُحذف المعسكر تلقائياً بعد انتهائه بـ 3 أيام.', style: TextStyle(fontSize: 11)),
        ]),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('إنشاء')),
      ],
    );
  }
}
