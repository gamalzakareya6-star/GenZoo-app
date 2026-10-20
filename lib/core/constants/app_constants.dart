class AppConstants {
  static const String appName = 'بوابة GenZoo الطلابية';
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

  static const List<String> semesters = [
    'الفصل الدراسي الأول',
    'الفصل الدراسي الثاني',
    'الفصل الصيفي',
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
