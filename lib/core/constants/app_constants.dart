class AppConstants {
  static const String appName = 'GenZoo';
  static const String appTagline = 'رفيقك الأكاديمي والروحي';

  // Firestore Collections
  static const String usersCollection = 'users';
  static const String newsCollection = 'news';
  static const String materialsCollection = 'materials';
  static const String quickLinksCollection = 'quick_links';
  static const String azkarCollection = 'azkar';

  // Academic Configuration
  static const List<String> academicYears = [
    'الفرقة الأولى',
    'الفرقة الثانية',
    'الفرقة الثالثة',
    'الفرقة الرابعة',
    'دراسات عليا',
  ];

  // Departments (used to organise the study materials).
  // Edit this list to add or rename a department.
  static const List<String> departments = [
    'علم الحيوان',
    'علم الحشرات',
    'علم النبات',
    'الميكروبيولوجي',
    'الكيمياء',
    'الكيمياء الحيوية',
    'الفيزياء',
    'الرياضيات',
    'علوم الحاسب',
    'الجيولوجيا',
    'مقررات عامة (كل الأقسام)',
  ];

  static const List<String> materialTypes = [
    'محاضرات',
    'كتاب / مرجع',
    'ملخص',
    'امتحانات سابقة',
    'دليل عملي / معمل',
  ];

  static const List<String> newsCategories = [
    'عام',
    'عاجل',
    'أكاديمي',
    'امتحانات',
    'أنشطة',
  ];
}
