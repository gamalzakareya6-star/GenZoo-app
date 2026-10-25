import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';

import '../core/services/update_service.dart';

/// Checks for an update once and, if there is one, offers to download and
/// install it from inside the app.
Future<void> checkForAppUpdate(BuildContext context) async {
  final update = await UpdateService.check();
  if (update == null || !context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _UpdateDialog(update: update),
  );
}

class _UpdateDialog extends StatefulWidget {
  final AppUpdate update;

  const _UpdateDialog({required this.update});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  StreamSubscription<OtaEvent>? _sub;
  bool _busy = false;
  double? _progress;
  String? _message;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() {
      _busy = true;
      _progress = null;
      _message = 'جارٍ تحميل التحديث...';
    });
    try {
      _sub = OtaUpdate()
          .execute(widget.update.apkUrl, destinationFilename: 'genzoo_update.apk')
          .listen((event) {
        if (!mounted) return;
        // Compared by name so the code does not depend on every enum member.
        final status = event.status.name;
        if (status == 'DOWNLOADING') {
          setState(() {
            _progress = (double.tryParse(event.value ?? '') ?? 0) / 100;
            _message = 'جارٍ التحميل ${event.value ?? ''}%';
          });
        } else if (status == 'INSTALLING') {
          setState(() {
            _progress = 1;
            _message = 'يتم فتح شاشة التثبيت، اضغط "تثبيت".';
          });
        } else if (status == 'INSTALLATION_DONE') {
          Navigator.of(context).pop();
        } else if (status == 'PERMISSION_NOT_GRANTED_ERROR') {
          _fail('لازم تسمح للتطبيق بتثبيت التحديثات من الإعدادات ثم حاول مرة أخرى.');
        } else {
          _fail('تعذّر إكمال التحديث. حاول مرة أخرى أو حمّل النسخة الجديدة يدوياً.');
        }
      }, onError: (_) => _fail('تعذّر تحميل التحديث. تأكد من الاتصال بالإنترنت.'));
    } catch (_) {
      _fail('تعذّر بدء التحديث.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final notes = widget.update.notes;
    return AlertDialog(
      title: const Text('يتوفر تحديث جديد'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('تم إصدار نسخة أحدث من GenZoo. يتم تحميلها وتثبيتها من داخل التطبيق.'),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(notes, style: const TextStyle(fontSize: 12.5)),
            ],
            if (_busy || _message != null) ...[
              const SizedBox(height: 14),
              if (_busy) LinearProgressIndicator(value: _progress),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_message!, style: const TextStyle(fontSize: 12.5)),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('لاحقاً'),
        ),
        FilledButton(
          onPressed: _busy ? null : _start,
          child: const Text('تحديث الآن'),
        ),
      ],
    );
  }
}
