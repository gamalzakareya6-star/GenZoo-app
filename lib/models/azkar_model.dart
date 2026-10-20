class AzkarItem {
  final String id;
  final String title;
  final String arabicText;
  final String? translation;
  final String? virtue; // Reference / Benefit
  final int targetCount;
  final String category; // 'study', 'morning', 'evening', 'daily'

  AzkarItem({
    required this.id,
    required this.title,
    required this.arabicText,
    this.translation,
    this.virtue,
    this.targetCount = 1,
    required this.category,
  });

  factory AzkarItem.fromMap(Map<String, dynamic> map, String id) {
    return AzkarItem(
      id: id,
      title: map['title'] ?? '',
      arabicText: map['arabicText'] ?? '',
      translation: map['translation'],
      virtue: map['virtue'],
      targetCount: (map['targetCount'] as num?)?.toInt() ?? 1,
      category: map['category'] ?? 'study',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'arabicText': arabicText,
      'translation': translation,
      'virtue': virtue,
      'targetCount': targetCount,
      'category': category,
    };
  }

  // Pre-seeded authentic collection of study duas & daily azkar
  static List<AzkarItem> getDefaultAzkar() {
    return [
      // Study Duas
      AzkarItem(
        id: 'study_1',
        title: 'دعاء قبل المذاكرة',
        arabicText: 'اللَّهُمَّ إِنِّي أَسْأَلُكَ فَهْمَ النَّبِيِّينَ، وَحِفْظَ الْمُرْسَلِينَ، وَالْمَلَائِكَةِ الْمُقَرَّبِينَ، اللَّهُمَّ اجْعَلْ أَلْسِنَتَنَا عَامِرَةً بِذِكْرِكَ، وَقُلُوبَنَا بِخَشْيَتِكَ، وَأَسْرَارَنَا بِطَاعَتِكَ، إِنَّكَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ.',
        virtue: 'يُقال عند الشروع في طلب العلم والمذاكرة لتيسير الفهم والحفظ',
        targetCount: 1,
        category: 'study',
      ),
      AzkarItem(
        id: 'study_2',
        title: 'دعاء تيسير الصعب',
        arabicText: 'اللَّهُمَّ لا سَهْلَ إِلاَّ ما جَعَلْتَهُ سَهْلاً، وأنْتَ تَجْعَلُ الحَزْنَ إِذَا شِئْتَ سَهْلاً.',
        virtue: 'دعاء نبوي شريف عند مواجهة مسألة أو امتحان صعب (صحيح ابن حبان)',
        targetCount: 3,
        category: 'study',
      ),
      AzkarItem(
        id: 'study_3',
        title: 'طلب زيادة العلم',
        arabicText: 'رَّبِّ زِدْنِي عِلْمًا',
        virtue: 'آية قرآنية كريمة جامعة لبركة العلم ودوام الفهم',
        targetCount: 7,
        category: 'study',
      ),
      AzkarItem(
        id: 'study_4',
        title: 'دعاء الانتهاء من المذاكرة',
        arabicText: 'اللَّهُمَّ إِنِّي أَسْتَوْدِعُكَ مَا قَرَأْتُ وَمَا حَفِظْتُ وَمَا تَعَلَّمْتُ، فَرُدَّهُ عَلَيَّ عِنْدَ حَاجَتِي إِلَيْهِ، إِنَّكَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ.',
        virtue: 'لحفظ العلم وتثبيته في الصدر حتى وقت الامتحان والعمل به',
        targetCount: 1,
        category: 'study',
      ),
      // Morning Azkar
      AzkarItem(
        id: 'morning_1',
        title: 'سيد الاستغفار',
        arabicText: 'اللَّهُمَّ أَنْتَ رَبِّي لاَ إِلَهَ إِلاَّ أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ، وَأَبُوءُ بِذَنْبِي فَاغْفِرْ لِي فَإِنَّهُ لاَ يَغْفِرُ الذُّنُوبَ إِلاَّ أَنْتَ.',
        virtue: 'من قالها موقناً بها حين يمسي فمات دخل الجنة (صحيح البخاري)',
        targetCount: 1,
        category: 'morning',
      ),
      AzkarItem(
        id: 'morning_2',
        title: 'آية الكرسي',
        arabicText: 'اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ ۚ لَّهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ ۗ مَن ذَا الَّذِي يَشْفَعُ عِندَهُ إِلَّا بِإِذْنِهِ ۚ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ ۖ وَلَا يُحِيطُونَ بِشَيْءٍ مِّنْ عِلْمِهِ إِلَّا بِمَا شَاءَ ۚ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ ۖ وَلَا يَئُودُهُ حِفْظُهُمَا ۚ وَهُوَ الْعَلِيُّ الْعَظِيمُ',
        virtue: 'من قرأها حين يصبح أجير من الجن حتى يمسي',
        targetCount: 1,
        category: 'morning',
      ),
      // Evening Azkar
      AzkarItem(
        id: 'evening_1',
        title: 'أمسينا وأمسى الملك لله',
        arabicText: 'أَمْسَيْنَا وَأَمْسَى المُلْكُ لِلَّهِ، وَالحَمْدُ لِلَّهِ لاَ إِلَهَ إِلاَّ اللَّهُ وَحْدَهُ لاَ شَرِيكَ لَهُ، لَهُ المُلْكُ وَلَهُ الحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ.',
        virtue: 'من أذكار المساء المأثورة عن رسول الله ﷺ',
        targetCount: 1,
        category: 'evening',
      ),
    ];
  }
}
