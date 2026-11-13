/// Arabic display names for values the app stores in English.
///
/// Stored values stay English so the backend sees one vocabulary; only the
/// screen (and the offline assistant) translate them.
abstract final class ArabicLabels {
  static String of(String value) => _labels[value] ?? value;

  static const Map<String, String> _labels = {
    'Not added': 'غير محدد',
    'Under 12': 'أقل من 12',
    '75 or older': '75 أو أكثر',
    'Prefer not to answer': 'أفضّل عدم الإجابة',
    'Female': 'أنثى',
    'Male': 'ذكر',
    // Food and drinks
    'Tea or coffee': 'الشاي أو القهوة',
    'Milk or calcium-rich foods': 'الحليب أو الأطعمة الغنية بالكالسيوم',
    'Grapefruit or pomelo': 'الجريب فروت أو البوملي',
    'Alcohol': 'الكحول',
    'Leafy greens / vitamin K': 'الخضار الورقية / فيتامين ك',
    'High-potassium foods or salt substitutes':
        'أطعمة غنية بالبوتاسيوم أو بدائل الملح',
    'Aged or fermented foods': 'الأطعمة المعتّقة أو المخمّرة',
    'High-fiber meals': 'وجبات غنية بالألياف',
    'Fasting or empty-stomach routine': 'الصيام أو معدة فارغة',
    'Tube feeding': 'التغذية بالأنبوب',
    // Supplements
    'Iron': 'الحديد',
    'Calcium': 'الكالسيوم',
    'Magnesium or zinc': 'المغنيسيوم أو الزنك',
    'Antacids': 'مضادات الحموضة',
    'Multivitamin': 'فيتامينات متعددة',
    'Herbal or natural products': 'أعشاب أو منتجات طبيعية',
    'St John’s wort': 'نبتة سانت جون',
    'Pain relievers': 'مسكنات الألم',
    'Cold or flu remedies': 'أدوية البرد والإنفلونزا',
    'Sleep aids': 'منومات',
    // Lifestyle
    'Smoking or nicotine': 'التدخين أو النيكوتين',
    'Cannabis or CBD': 'القنب أو CBD',
    'Shift work': 'عمل بنظام المناوبات',
    'Frequent travel / timezone changes': 'سفر متكرر / تغيّر التوقيت',
    'Religious or intermittent fasting': 'صيام (رمضان أو متقطع)',
    'Recent vomiting or diarrhea': 'قيء أو إسهال مؤخراً',
    'Upcoming surgery or procedure': 'عملية أو إجراء طبي قريب',
    // Accessibility
    'Larger text and buttons': 'خط وأزرار أكبر',
    'Voice input': 'الإدخال الصوتي',
    'Vision support': 'دعم ضعف البصر',
    'Hearing support': 'دعم ضعف السمع',
    'Dexterity support': 'دعم صعوبة الحركة',
    'Memory support': 'دعم التذكّر',
    'Caregiver helps with medicines': 'مرافق يساعد في الأدوية',
  };
}
