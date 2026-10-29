import 'package:cloud_firestore/cloud_firestore.dart';

class QuickLink {
  final String id;
  final String title;
  final String description;
  final String url;
  final String category; // 'Portal', 'Registration', 'Schedule', 'Library', 'LMS'
  final String iconName; // e.g., 'school', 'assignment', 'calendar_today', 'menu_book'
  final int order;

  QuickLink({
    required this.id,
    required this.title,
    required this.description,
    required this.url,
    this.category = 'General',
    this.iconName = 'link',
    this.order = 0,
  });

  factory QuickLink.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return QuickLink(
      id: doc.id,
      title: data['title'] as String? ?? 'رابط',
      description: data['description'] as String? ?? '',
      url: data['url'] as String? ?? 'https://',
      category: data['category'] as String? ?? 'General',
      iconName: data['iconName'] as String? ?? 'link',
      order: (data['order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'url': url,
      'category': category,
      'iconName': iconName,
      'order': order,
    };
  }

  static List<QuickLink> getDefaultLinks() {
    return [
      QuickLink(
        id: '1',
        title: 'بوابة الطالب الرسمية',
        description: 'تسجيل المقررات والدرجات والموقف المالي والسجلات الرسمية',
        url: 'https://portal.university.edu',
        category: 'Portal',
        iconName: 'school',
        order: 1,
      ),
      QuickLink(
        id: '2',
        title: 'منصة التعليم الإلكتروني (LMS / Moodle)',
        description: 'تسجيلات المحاضرات وتسليم التكليفات والاختبارات الأسبوعية',
        url: 'https://lms.university.edu',
        category: 'LMS',
        iconName: 'laptop_chromebook',
        order: 2,
      ),
      QuickLink(
        id: '3',
        title: 'الجداول الدراسية للفصل',
        description: 'مواعيد المحاضرات ومجموعات المعمل وامتحانات منتصف الفصل والنهائي',
        url: 'https://university.edu/schedules',
        category: 'Schedule',
        iconName: 'calendar_month',
        order: 3,
      ),
      QuickLink(
        id: '4',
        title: 'تسجيل المقررات والحذف والإضافة',
        description: 'اختيار مقررات الفصل وموافقات المرشد الأكاديمي',
        url: 'https://university.edu/registration',
        category: 'Registration',
        iconName: 'how_to_reg',
        order: 4,
      ),
      QuickLink(
        id: '5',
        title: 'المكتبة الجامعية الرقمية',
        description: 'الدوريات العلمية وأرشيف الرسائل وقواعد البيانات البحثية',
        url: 'https://library.university.edu',
        category: 'Library',
        iconName: 'menu_book',
        order: 5,
      ),
    ];
  }
}
