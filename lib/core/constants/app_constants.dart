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

  // البرامج الدراسية كما وردت في لائحة البكالوريوس - قائمة موحدة للاختيار.
  static const List<String> academicPrograms = [
    'الفيزياء',
    'الرياضيات',
    'الكيمياء',
    'الجيولوجيا',
    'علم النبات',
    'علم الحيوان',
    'الحشرات',
    'جيولوجيا البترول',
    'الجيوفيزياء',
    'الفيزياء والكيمياء',
    'الفيزياء والجيولوجيا',
    'الفيزياء وعلوم الحاسب',
    'الكيمياء والجيولوجيا',
    'الكيمياء والكيمياء الحيوية',
    'الكيمياء والنبات',
    'الكيمياء والحيوان',
    'الكيمياء والحشرات',
    'الكيمياء والميكروبيولوجي',
    'الرياضيات البحتة والفيزياء',
    'الرياضيات البحتة وعلوم الحاسب',
    'رياضيات بحتة وإحصاء',
    'الفيزياء وعلوم الليزر',
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
