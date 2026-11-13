import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/ibn_haytham_service.dart';

/// منصة ابن الهيثم — entry point.
///
/// Shows a one-time login form (الرقم القومي + كلمة المرور) the first time,
/// then stores the credentials encrypted on the device only (never sent to
/// GenZoo's own servers) and goes straight to the in-app portal on every
/// visit after that.
class IbnHaythamScreen extends StatefulWidget {
  const IbnHaythamScreen({super.key});

  @override
  State<IbnHaythamScreen> createState() => _IbnHaythamScreenState();
}

class _IbnHaythamScreenState extends State<IbnHaythamScreen> {
  bool _loading = true;
  ({String nationalId, String password})? _creds;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final creds = await IbnHaythamService.readCredentials();
    if (!mounted) return;
    setState(() {
      _creds = creds;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_creds == null) {
      return _IbnHaythamLoginForm(
        onSaved: (c) => setState(() => _creds = c),
      );
    }
    return _IbnHaythamPortal(
      nationalId: _creds!.nationalId,
      password: _creds!.password,
      onForgetCredentials: () async {
        await IbnHaythamService.clearCredentials();
        if (!mounted) return;
        setState(() => _creds = null);
      },
    );
  }
}

class _IbnHaythamLoginForm extends StatefulWidget {
  final ValueChanged<({String nationalId, String password})> onSaved;
  const _IbnHaythamLoginForm({required this.onSaved});

  @override
  State<_IbnHaythamLoginForm> createState() => _IbnHaythamLoginFormState();
}

class _IbnHaythamLoginFormState extends State<_IbnHaythamLoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _idCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _saving = false;

  @override
  void dispose() {
    _idCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final id = _idCtrl.text.trim();
    final pass = _passCtrl.text;
    await IbnHaythamService.saveCredentials(nationalId: id, password: pass);
    if (!mounted) return;
    widget.onSaved((nationalId: id, password: pass));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ابن الهيثم')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.school_rounded, size: 72, color: AppColors.primary),
                    const SizedBox(height: 12),
                    const Text(
                      'سجّل دخولك لمنصة ابن الهيثم',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'هتدخل من هنا على طول من غير ما تحتاج تمسح بيانات المتصفح أو تفتح وضع التصفح الخفي — التطبيق بيعمل ده تلقائي في كل مرة.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _idCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'الرقم القومي',
                        prefixIcon: Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'بياناتك دي بتتخزن مشفّرة على جهازك فقط، ومش بترسل لسيرفرات GenZoo — بتتبعت لمنصة ابن الهيثم الرسمية بس عشان تسجّل دخولك.',
                      style: TextStyle(fontSize: 12, color: Colors.black45),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _saving ? null : _submit,
                      child: _saving
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('دخول'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The 5 quick-access shortcuts, matched against the platform's own menu
/// text so this keeps working even if the platform changes its own HTML
/// structure/classes — only the visible Arabic label needs to still exist.
class _Shortcut {
  final String label;
  final IconData icon;
  final List<String> matchKeywords;
  final bool hasPrintOnPlatform;
  final bool seasonalOnly;
  const _Shortcut(this.label, this.icon, this.matchKeywords, {this.hasPrintOnPlatform = false, this.seasonalOnly = false});
}

const _shortcuts = <_Shortcut>[
  _Shortcut('استمارة التسجيل', Icons.assignment_rounded, ['استمارة التسجيل'], hasPrintOnPlatform: true),
  _Shortcut('تقدير المقررات', Icons.grade_rounded, ['تقدير المقررات', 'تقدير مقررات']),
  _Shortcut('الجدول الدراسي', Icons.calendar_view_week_rounded, ['الجدول الدراسي'], hasPrintOnPlatform: true),
  _Shortcut('التسجيل الأكاديمي', Icons.how_to_reg_rounded, ['التسجيل الأكاديمي', 'التسجيل الاكاديمي'], seasonalOnly: true),
  _Shortcut('جدول الامتحانات', Icons.event_note_rounded, ['جدول الامتحانات']),
];

const _platformUrl = 'https://stdch.menofia.education/static/index.html';

class _IbnHaythamPortal extends StatefulWidget {
  final String nationalId;
  final String password;
  final VoidCallback onForgetCredentials;
  const _IbnHaythamPortal({
    required this.nationalId,
    required this.password,
    required this.onForgetCredentials,
  });

  @override
  State<_IbnHaythamPortal> createState() => _IbnHaythamPortalState();
}

class _IbnHaythamPortalState extends State<_IbnHaythamPortal> {
  WebViewController? _controller;
  final GlobalKey _repaintKey = GlobalKey();
  bool _pageLoading = true;
  bool _autoFillTried = false;
  String? _studentName;
  String? _studentDept;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  Future<void> _initController() async {
    // Simulate the "incognito / cleared site data" state the real platform
    // needs to work reliably, automatically, every time — so the student
    // never has to know about this workaround themselves.
    final cookieManager = WebViewCookieManager();
    await cookieManager.clearCookies();

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFFFFFF))
      ..addJavaScriptChannel(
        'IbnHaytham',
        onMessageReceived: _onChannelMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _pageLoading = true),
          onPageFinished: (_) async {
            setState(() => _pageLoading = false);
            if (!_autoFillTried) {
              _autoFillTried = true;
              await Future.delayed(const Duration(milliseconds: 400));
              await _tryAutoLogin();
            }
            await _tryExtractProfile();
          },
        ),
      )
      ..loadRequest(Uri.parse(_platformUrl));

    setState(() => _controller = controller);
  }

  void _onChannelMessage(JavaScriptMessage message) {
    // Reserved for when the real HTML selectors are known: the extraction
    // script will postMessage the student's name/department/grades here
    // via IbnHaytham.postMessage(...). Kept generic until then.
    final data = message.message;
    if (data.startsWith('name:')) {
      setState(() => _studentName = data.substring(5));
    } else if (data.startsWith('dept:')) {
      setState(() => _studentDept = data.substring(5));
    }
  }

  /// Heuristic auto-login: find the password field, find the nearest text
  /// input before it inside the same form (the National ID field, whatever
  /// its name/id/class happens to be), fill both, and submit the form.
  /// This stays robust even if the platform renames its fields, as long as
  /// the form still has exactly one password input.
  Future<void> _tryAutoLogin() async {
    final js =
        '''
    (function() {
      try {
        var pass = document.querySelector('input[type="password"]');
        if (!pass) return 'no_password_field';
        var form = pass.closest('form') || document;
        var inputs = Array.prototype.slice.call(form.querySelectorAll('input'));
        var idField = null;
        for (var i = 0; i < inputs.length; i++) {
          var el = inputs[i];
          if (el === pass) break;
          var t = (el.type || 'text').toLowerCase();
          if (['text','tel','number','search','email'].indexOf(t) !== -1 && !el.disabled) {
            idField = el;
          }
        }
        if (!idField) return 'no_id_field';

        function setVal(el, val) {
          var proto = Object.getPrototypeOf(el);
          var setter = Object.getOwnPropertyDescriptor(proto, 'value');
          if (setter && setter.set) { setter.set.call(el, val); } else { el.value = val; }
          el.dispatchEvent(new Event('input', { bubbles: true }));
          el.dispatchEvent(new Event('change', { bubbles: true }));
        }
        setVal(idField, ${_jsStr(widget.nationalId)});
        setVal(pass, ${_jsStr(widget.password)});

        var submitBtn = form.querySelector('button[type="submit"], input[type="submit"]');
        if (submitBtn) { submitBtn.click(); }
        else if (form.requestSubmit) { form.requestSubmit(); }
        else if (form.submit) { form.submit(); }
        return 'submitted';
      } catch (e) { return 'error:' + e.message; }
    })();
    ''';
    try {
      await _controller!.runJavaScript(js);
    } catch (_) {
      // Ignore — the student can still fill the platform's own form by hand.
    }
  }

  /// Placeholder — will be completed once the real post-login page HTML is
  /// available, to read the student's name/department and post them back
  /// via the IbnHaytham channel. For now this is a no-op so nothing breaks.
  Future<void> _tryExtractProfile() async {
    // TODO: fill in real selectors once the saved HTML sample arrives, e.g.
    // IbnHaytham.postMessage('name:' + document.querySelector('...').textContent)
  }

  String _jsStr(String s) {
    final escaped = s.replaceAll('\\', '\\\\').replaceAll("'", "\\'");
    return "'$escaped'";
  }

  Future<void> _openShortcut(_Shortcut s) async {
    final keywordsJs = '[${s.matchKeywords.map(_jsStr).join(',')}]';
    final js =
        '''
    (function() {
      var keywords = $keywordsJs;
      var all = Array.prototype.slice.call(document.querySelectorAll('a, button, li, span, div'));
      for (var i = 0; i < all.length; i++) {
        var el = all[i];
        var text = (el.textContent || '').trim();
        if (!text || text.length > 60) continue;
        for (var k = 0; k < keywords.length; k++) {
          if (text.indexOf(keywords[k]) !== -1) {
            var clickable = el.closest('a, button') || el;
            clickable.click();
            return 'clicked';
          }
        }
      }
      return 'not_found';
    })();
    ''';
    try {
      final result = await _controller!.runJavaScriptReturningResult(js);
      if (result.toString().contains('not_found') && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('مقدرتش ألاقي "${s.label}" في الصفحة الحالية — جرّب ترجع للصفحة الرئيسية للمنصة.')),
        );
      }
    } catch (_) {}

    if (s.seasonalOnly && mounted) {
      // Academic registration only works in specific windows of the year;
      // the platform itself shows an error outside those windows. We can't
      // reliably read its exact wording without the real HTML yet, so for
      // now we give the student a clear heads-up instead of a confusing
      // raw platform error.
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'ملحوظة: "التسجيل الأكاديمي" بيشتغل بس في فترات محددة من السنة. لو ظهرت رسالة خطأ على المنصة، فده معناه إن الفترة الحالية لسه مقفولة.',
          ),
          duration: Duration(seconds: 5),
        ),
      );
    }

    if (!s.hasPrintOnPlatform && mounted) {
      // No print button on the platform for this page (e.g. جدول الامتحانات)
      // — offer our own screenshot-based share/save as an interim solution.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('الصفحة دي مفيهاش زر طباعة على المنصة — ممكن تستخدم زر المشاركة فوق لحفظها كصورة.'),
          action: SnackBarAction(label: 'مشاركة دلوقتي', onPressed: _shareScreenshot),
        ),
      );
    }
  }

  /// Interim fallback for pages with no print button on the real platform
  /// (currently جدول الامتحانات): captures what's on screen and lets the
  /// student share/save it as an image instead.
  Future<void> _shareScreenshot() async {
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/ibn_haytham_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'من تطبيق GenZoo — منصة ابن الهيثم');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّرت المشاركة، جرّب تاخد سكرين شوت عادي من جهازك.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _studentName != null
              ? _studentDept != null ? '$_studentName • $_studentDept' : _studentName!
              : 'ابن الهيثم',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'مشاركة/حفظ الصفحة كصورة',
            onPressed: _shareScreenshot,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
            onPressed: () => _controller!.reload(),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'forget') widget.onForgetCredentials();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'forget', child: Text('نسيان بيانات الدخول المحفوظة')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_pageLoading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: RepaintBoundary(
              key: _repaintKey,
              child: WebViewWidget(controller: _controller!),
            ),
          ),
          SafeArea(
            top: false,
            child: SizedBox(
              height: 86,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: _shortcuts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final s = _shortcuts[i];
                  return _ShortcutChip(shortcut: s, onTap: () => _openShortcut(s));
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutChip extends StatelessWidget {
  final _Shortcut shortcut;
  final VoidCallback onTap;
  const _ShortcutChip({required this.shortcut, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 92,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(shortcut.icon, color: AppColors.primary),
            const SizedBox(height: 4),
            Text(
              shortcut.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
