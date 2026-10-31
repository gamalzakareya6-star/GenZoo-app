import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_palette.dart';
import '../../providers/appearance_provider.dart';
import '../../widgets/animations.dart';

/// المظهر والتخصيص: colors, interface style, dark mode, font and home layout.
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ap = context.watch<AppearanceProvider>();
    final theme = Theme.of(context);

    Widget section(String title, IconData icon, Widget child, int i) => FadeSlideIn(
          index: i,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icon, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ]),
              const SizedBox(height: 10),
              child,
            ]),
          ),
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('المظهر والتخصيص'),
        actions: [
          TextButton.icon(
            onPressed: () => context.read<AppearanceProvider>().reset(),
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
            label: const Text('إعادة ضبط'),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        section(
          'وضع العرض',
          Icons.brightness_6_rounded,
          Column(children: [
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_rounded), label: Text('تلقائي')),
                  ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_rounded), label: Text('فاتح')),
                  ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_rounded), label: Text('داكن')),
                ],
                selected: {ap.mode},
                onSelectionChanged: (v) => context.read<AppearanceProvider>().setMode(v.first),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: ap.amoled,
              onChanged: (v) => context.read<AppearanceProvider>().setAmoled(v),
              title: const Text('أسود كامل (AMOLED)'),
              subtitle: const Text('خلفية سوداء في الوضع الداكن لتوفير البطارية'),
            ),
          ]),
          0,
        ),
        section(
          'لون التطبيق',
          Icons.color_lens_rounded,
          Wrap(spacing: 12, runSpacing: 12, children: [
            for (final p in AppPalette.presets)
              GestureDetector(
                onTap: () => context.read<AppearanceProvider>().setPalette(p),
                child: SizedBox(
                  width: 78,
                  child: Column(children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [p.primary, p.secondary],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                        border: Border.all(
                          color: ap.palette.id == p.id ? theme.colorScheme.onSurface : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: ap.palette.id == p.id ? const Icon(Icons.check_rounded, color: Colors.white) : null,
                    ),
                    const SizedBox(height: 4),
                    Text(p.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5)),
                  ]),
                ),
              ),
          ]),
          1,
        ),
        section(
          'شكل الواجهة',
          Icons.dashboard_customize_rounded,
          Column(children: [
            for (final s in UiStyle.values)
              _StyleTile(style: s, selected: ap.style == s, onTap: () => context.read<AppearanceProvider>().setStyle(s)),
          ]),
          2,
        ),
        section(
          'الخط والحجم',
          Icons.text_fields_rounded,
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 8, children: [
              for (final f in AppFont.values)
                ChoiceChip(
                  label: Text(f.label),
                  selected: ap.font == f,
                  onSelected: (_) => context.read<AppearanceProvider>().setFont(f),
                ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              const Text('حجم الخط'),
              Expanded(
                child: Slider(
                  value: ap.fontScale,
                  min: 0.85,
                  max: 1.35,
                  divisions: 10,
                  label: '${(ap.fontScale * 100).round()}%',
                  onChanged: (v) => context.read<AppearanceProvider>().setFontScale(v),
                ),
              ),
              Text('${(ap.fontScale * 100).round()}%'),
            ]),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text('نموذج: خطوة صغيرة كل يوم تصنع فرقاً كبيراً في النهاية.', style: theme.textTheme.bodyLarge),
              ),
            ),
          ]),
          3,
        ),
        section(
          'الصفحة الرئيسية والكثافة',
          Icons.view_agenda_rounded,
          Column(children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: ap.compact,
              onChanged: (v) => context.read<AppearanceProvider>().setCompact(v),
              title: const Text('عرض مضغوط'),
              subtitle: const Text('مسافات أصغر لعرض محتوى أكثر'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: ap.showBanner,
              onChanged: (v) => context.read<AppearanceProvider>().setShowBanner(v),
              title: const Text('لافتة الترحيب'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: ap.showDaily,
              onChanged: (v) => context.read<AppearanceProvider>().setShowDaily(v),
              title: const Text('كارت "يومي" (السلسلة والتحفيز)'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: ap.showForest,
              onChanged: (v) => context.read<AppearanceProvider>().setShowForest(v),
              title: const Text('كارت تحدي الـ100 شجرة'),
            ),
          ]),
          4,
        ),
        const SizedBox(height: 30),
      ]),
    );
  }
}

class _StyleTile extends StatelessWidget {
  final UiStyle style;
  final bool selected;
  final VoidCallback onTap;
  const _StyleTile({required this.style, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final radius = switch (style) { UiStyle.modern => 16.0, UiStyle.flat => 6.0, UiStyle.soft => 24.0 };
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: selected ? AppColors.primary : Colors.transparent, width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            // Mini preview of a card in this style.
            Container(
              width: 76,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius.clamp(4, 14)),
                border: style == UiStyle.modern ? Border.all(color: Colors.grey.shade400) : null,
                boxShadow: style == UiStyle.soft
                    ? [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 8, offset: const Offset(0, 3))]
                    : null,
                color: style == UiStyle.flat ? scheme.onSurface.withOpacity(0.06) : scheme.surface,
              ),
              child: Center(
                child: Container(
                  width: 40,
                  height: 8,
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(style.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(style.description, style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
              ]),
            ),
            if (selected) Icon(Icons.check_circle_rounded, color: AppColors.primary),
          ]),
        ),
      ),
    );
  }
}
