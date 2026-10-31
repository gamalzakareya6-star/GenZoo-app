import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_palette.dart';

/// Interface styles the student can choose between.
enum UiStyle { modern, flat, soft }

enum AppFont { cairo, tajawal, almarai, naskh }

extension UiStyleLabel on UiStyle {
  String get label => switch (this) {
        UiStyle.modern => 'عصري',
        UiStyle.flat => 'مسطح بسيط',
        UiStyle.soft => 'ناعم',
      };
  String get description => switch (this) {
        UiStyle.modern => 'بطاقات بإطار رفيع',
        UiStyle.flat => 'بدون إطارات وحواف أصغر',
        UiStyle.soft => 'حواف دائرية وظلال خفيفة',
      };
}

extension AppFontLabel on AppFont {
  String get label => switch (this) {
        AppFont.cairo => 'القاهرة',
        AppFont.tajawal => 'تجوال',
        AppFont.almarai => 'المراعي',
        AppFont.naskh => 'نسخ',
      };
}

/// Everything about how the app looks that the student can customize. It is
/// saved on the device and applied live.
class AppearanceProvider extends ChangeNotifier {
  static const _key = 'appearance_v1';

  AppPalette _palette = AppPalette.presets.first;
  ThemeMode _mode = ThemeMode.system;
  UiStyle _style = UiStyle.modern;
  AppFont _font = AppFont.cairo;
  double _fontScale = 1.0;
  bool _compact = false;
  bool _amoled = false;
  bool _showBanner = true;
  bool _showDaily = true;
  bool _showForest = true;

  AppearanceProvider() {
    _load();
  }

  AppPalette get palette => _palette;
  ThemeMode get mode => _mode;
  UiStyle get style => _style;
  AppFont get font => _font;
  double get fontScale => _fontScale;
  bool get compact => _compact;
  bool get amoled => _amoled;
  bool get showBanner => _showBanner;
  bool get showDaily => _showDaily;
  bool get showForest => _showForest;

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      if (raw == null) return;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      _palette = AppPalette.byId(j['palette'] as String?);
      _mode = ThemeMode.values.firstWhere((m) => m.name == j['mode'], orElse: () => ThemeMode.system);
      _style = UiStyle.values.firstWhere((m) => m.name == j['style'], orElse: () => UiStyle.modern);
      _font = AppFont.values.firstWhere((m) => m.name == j['font'], orElse: () => AppFont.cairo);
      _fontScale = ((j['scale'] as num?)?.toDouble() ?? 1.0).clamp(0.85, 1.35);
      _compact = j['compact'] as bool? ?? false;
      _amoled = j['amoled'] as bool? ?? false;
      _showBanner = j['banner'] as bool? ?? true;
      _showDaily = j['daily'] as bool? ?? true;
      _showForest = j['forest'] as bool? ?? true;
    } catch (_) {}
    AppColors.palette = _palette;
    notifyListeners();
    _rebuildAll();
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
        _key,
        jsonEncode({
          'palette': _palette.id,
          'mode': _mode.name,
          'style': _style.name,
          'font': _font.name,
          'scale': _fontScale,
          'compact': _compact,
          'amoled': _amoled,
          'banner': _showBanner,
          'daily': _showDaily,
          'forest': _showForest,
        }),
      );
    } catch (_) {}
  }

  void _changed({bool colors = false}) {
    if (colors) AppColors.palette = _palette;
    notifyListeners();
    _save();
    if (colors) _rebuildAll();
  }

  /// Widgets that read the brand colors directly do not listen to anything, so
  /// after a palette change every element is marked for rebuild (the
  /// navigation stack and screen state are kept).
  void _rebuildAll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      void visit(Element e) {
        e.markNeedsBuild();
        e.visitChildren(visit);
      }

      WidgetsBinding.instance.rootElement?.visitChildren(visit);
    });
  }

  void setPalette(AppPalette p) {
    _palette = p;
    _changed(colors: true);
  }

  void setMode(ThemeMode m) {
    _mode = m;
    _changed(colors: true);
  }

  void setStyle(UiStyle s) {
    _style = s;
    _changed();
  }

  void setFont(AppFont f) {
    _font = f;
    _changed();
  }

  void setFontScale(double v) {
    _fontScale = v.clamp(0.85, 1.35);
    _changed();
  }

  void setCompact(bool v) {
    _compact = v;
    _changed();
  }

  void setAmoled(bool v) {
    _amoled = v;
    _changed();
  }

  void setShowBanner(bool v) {
    _showBanner = v;
    _changed();
  }

  void setShowDaily(bool v) {
    _showDaily = v;
    _changed();
  }

  void setShowForest(bool v) {
    _showForest = v;
    _changed();
  }

  void reset() {
    _palette = AppPalette.presets.first;
    _mode = ThemeMode.system;
    _style = UiStyle.modern;
    _font = AppFont.cairo;
    _fontScale = 1.0;
    _compact = false;
    _amoled = false;
    _showBanner = _showDaily = _showForest = true;
    _changed(colors: true);
  }
}
