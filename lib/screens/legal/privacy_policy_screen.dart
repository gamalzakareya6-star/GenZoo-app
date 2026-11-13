import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Standalone page: opened from the registration screen (must be read before
/// creating an account) and from the app drawer at any time afterwards.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _sections = <(String, String)>[
    (
      'البيانات التي نجمعها',
      'عند إنشاء حساب نحفظ: اسمك، بريدك الإلكتروني، رقم هاتفك، وفرقتك الدراسية. '
          'لا نطلب أي بيانات مالية أو حساسة. عند استخدامك ميزات التطبيق قد نحفظ أيضاً: '
          'الملفات التي ترفعها أو تعدّلها، رسائل المحادثات داخل معسكرات المذاكرة، '
          'تقييماتك وآراءك عن المواد، وإحصاءات بسيطة عن مذاكرتك (مثل أيام التتابع وعدد الأشجار).',
    ),
    (
      'كيف نستخدم بياناتك',
      'تُستخدم بياناتك فقط لتشغيل خدمات التطبيق: عرض اسمك للمشرفين والزملاء في المعسكرات، '
          'التواصل معك بإشعارات عن المواد والمحادثات والمواعيد، ومراجعة الملفات التي تطلب نشرها '
          'قبل إتاحتها لباقي الطلاب. لا نستخدم بياناتك في الإعلانات الموجّهة، ولا نحلّلها لأغراض تجارية.',
    ),
    (
      'حماية ملفاتك وبياناتك',
      'بموافقتك على هذه السياسة، فإن كل ملف ترفعه وكل بيانات حسابك داخل التطبيق تخضع لحماية الخصوصية '
          'الموضحة هنا: لا يصل إليها إلا أنت، ومن تشاركه مباشرة (مثل زملائك في نفس معسكر المذاكرة)، '
          'والمشرفون عند مراجعة طلب نشر ملف فقط. لا نطّلع على ملفاتك الشخصية أو نسخك المحمّلة على '
          'جهازك (مثل الملفات المفتوحة من خارج التطبيق)، ولا يملك أي مشرف صلاحية الوصول إلى جهازك.',
    ),
    (
      'من يخزّن بياناتك',
      'تُخزَّن بياناتك في قواعد بيانات Firebase (التابعة لشركة Google) بحماية وتشفير قياسيين في الصناعة. '
          'بعض الملفات الكبيرة قد تُرفع عبر Google Drive بصلاحية وصول مخصصة للتطبيق فقط. المواد التي ينشرها '
          'القسم عبر قناة تيليجرام الرسمية تُنسخ تلقائياً داخل التطبيق لتسهيل الوصول إليها دون إنترنت.',
    ),
    (
      'مشاركة البيانات',
      'لا نبيع بياناتك ولا نشاركها مع أي جهة خارج نطاق تشغيل التطبيق. الاستثناء الوحيد هو الالتزام '
          'بطلب قانوني رسمي من جهة مختصة، أو لحماية سلامة الطلاب عند وجود خطر حقيقي.',
    ),
    (
      'التحكم في بياناتك',
      'يمكنك في أي وقت تعديل بياناتك الشخصية من "ملفي الشخصي"، أو حذف ملف رفعته بنفسك قبل موافقة '
          'المشرف عليه. لطلب حذف حسابك بالكامل أو أي بيانات متعلقة به، تواصل مع إدارة التطبيق عبر '
          'المشرفين داخل التطبيق.',
    ),
    (
      'التغييرات على هذه السياسة',
      'قد تُحدَّث هذه السياسة مستقبلاً لمواكبة ميزات جديدة. سيظهر إشعار داخل التطبيق عند أي تعديل '
          'جوهري، وتبقى نسخة هذه الصفحة متاحة لك دائماً من القائمة الجانبية.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سياسة الخصوصية')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Icon(Icons.privacy_tip_rounded, color: AppColors.primary, size: 28),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'خصوصية بياناتك وملفاتك على GenZoo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'آخر تحديث: نوفمبر 2026',
            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
          ),
          const SizedBox(height: 18),
          for (final s in _sections) _Section(title: s.$1, body: s.$2),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'بإنشائك حساباً على GenZoo فإنك توافق على هذه السياسة بالكامل.',
              style: TextStyle(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;
  const _Section({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(fontSize: 13.5, height: 1.7)),
        ],
      ),
    );
  }
}
