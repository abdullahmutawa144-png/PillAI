import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../domain/app_models.dart';
import '../../domain/arabic_labels.dart';
import '../bidi.dart';

/// Every user-facing string, in English and Arabic side by side.
///
/// Keeping both languages on the same line makes it hard to add a string to
/// one language and forget the other. Arabic uses clear Modern Standard
/// Arabic for instructions and Saudi phrasing only for sample user messages.
class AppStrings {
  const AppStrings(this.language);

  final AppLanguage language;

  static const List<Locale> supportedLocales = [Locale('en'), Locale('ar')];

  static const LocalizationsDelegate<AppStrings> delegate =
      _AppStringsDelegate();

  static AppStrings of(BuildContext context) {
    return Localizations.of<AppStrings>(context, AppStrings) ??
        const AppStrings(AppLanguage.english);
  }

  bool get isArabic => language == AppLanguage.arabic;

  String _t(String en, String ar) => isArabic ? ar : en;

  /// Arabic counted nouns change form for 1, 2, 3–10 and 11+.
  String _count(
    int n, {
    required String en,
    required String enPlural,
    required String arOne,
    required String arTwo,
    required String arFew,
    required String arMany,
  }) {
    if (!isArabic) return '$n ${n == 1 ? en : enPlural}';
    if (n == 1) return arOne;
    if (n == 2) return arTwo;
    if (n >= 3 && n <= 10) return '$n $arFew';
    return '$n $arMany';
  }

  // ---------------------------------------------------------------------------
  // Formatting

  String time(DateTime value) => timeOfMinutes(value.hour * 60 + value.minute);

  String timeOfMinutes(int minutes) {
    final hour24 = minutes ~/ 60;
    final minute = (minutes % 60).toString().padLeft(2, '0');
    final hour = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final suffix = hour24 < 12 ? _t('AM', 'ص') : _t('PM', 'م');
    return '$hour:$minute $suffix';
  }

  /// "7 AM" when on the hour, otherwise the full time.
  String compactTimeOfMinutes(int minutes) {
    if (minutes % 60 != 0) return timeOfMinutes(minutes);
    final hour24 = minutes ~/ 60;
    final hour = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return '$hour ${hour24 < 12 ? _t('AM', 'ص') : _t('PM', 'م')}';
  }

  static const _weekdaysEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _weekdaysLongEn = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _weekdaysAr = [
    'إثنين',
    'ثلاثاء',
    'أربعاء',
    'خميس',
    'جمعة',
    'سبت',
    'أحد',
  ];
  static const _weekdaysLongAr = [
    'الإثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];
  static const _monthsEn = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  static const _monthsAr = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  String weekdayShort(DateTime value) => isArabic
      ? _weekdaysAr[value.weekday - 1]
      : _weekdaysEn[value.weekday - 1];

  String weekdayLong(DateTime value) => isArabic
      ? _weekdaysLongAr[value.weekday - 1]
      : _weekdaysLongEn[value.weekday - 1];

  String monthDay(DateTime value) => isArabic
      ? '${value.day} ${_monthsAr[value.month - 1]}'
      : '${_monthsEn[value.month - 1]} ${value.day}';

  /// "Wednesday, Oct 1" / "الأربعاء، 1 أكتوبر".
  String dateLong(DateTime value) =>
      '${weekdayLong(value)}${_t(', ', '، ')}${monthDay(value)}';

  /// "Today", "Tomorrow", "Yesterday", or the weekday and date.
  String relativeDay(DateTime day, DateTime today) {
    final a = DateTime.utc(day.year, day.month, day.day);
    final b = DateTime.utc(today.year, today.month, today.day);
    final diff = a.difference(b).inDays;
    if (diff == 0) return todayLabel;
    if (diff == 1) return _t('Tomorrow', 'غداً');
    if (diff == -1) return _t('Yesterday', 'أمس');
    return dateLong(day);
  }

  // ---------------------------------------------------------------------------
  // Common

  String get appName => 'PillAI';
  String get cancel => _t('Cancel', 'إلغاء');
  String get save => _t('Save', 'حفظ');
  String get done => _t('Done', 'تم');
  String get close => _t('Close', 'إغلاق');
  String get continueLabel => _t('Continue', 'متابعة');
  String get notNow => _t('Not now', 'ليس الآن');
  String get undo => _t('Undo', 'تراجع');
  String get delete => _t('Delete', 'حذف');
  String get edit => _t('Edit', 'تعديل');
  String get gotIt => _t('Got it', 'حسناً');
  String get todayLabel => _t('Today', 'اليوم');
  String get on => _t('On', 'مفعّلة');
  String get off => _t('Off', 'متوقفة');

  // ---------------------------------------------------------------------------
  // Navigation

  String get tabToday => _t('Today', 'اليوم');
  String get tabAssistant => _t('Assistant', 'المساعد');
  String get tabMedicines => _t('Medicines', 'أدويتي');
  String get tabProfile => _t('Profile', 'حسابي');

  // ---------------------------------------------------------------------------
  // Today

  String greeting(DateTime now, String name) {
    final hour = now.hour;
    final base = hour < 12
        ? _t('Good morning', 'صباح الخير')
        : hour < 17
        ? _t('Good afternoon', 'مساء الخير')
        : _t('Good evening', 'مساء الخير');
    final trimmed = name.trim();
    if (trimmed.isEmpty) return base;
    return '$base${_t(', ', '، ')}$trimmed';
  }

  String get askBarHint =>
      _t('Tell PillAI what happened…', 'أخبر PillAI بما حدث أو اسأله…');
  String get typeMessage => _t('Type', 'اكتب');
  String get talkToPillAi => _t('Talk to PillAI', 'تحدّث مع PillAI');
  String get nextDose => _t('Next dose', 'الجرعة القادمة');
  String get dueNow => _t('Due now', 'حان الموعد');
  String get overdue => _t('Overdue', 'متأخرة');
  String get upcoming => _t('Upcoming', 'قادمة');
  String get taken => _t('Taken', 'أخذتها');
  String get later => _t('Later', 'لاحقاً');
  String get missed => _t('Missed', 'فاتتني');
  String get allDoneTitle => _t('All done for today', 'أنهيت أدوية اليوم');
  String get allDoneBody =>
      _t('Nice work. Your plan is up to date.', 'أحسنت! خطتك مكتملة.');
  String get setupTitle => _t('Let’s set up your medicines', 'لنرتّب أدويتك');
  String get setupBody => _t(
    'Add what you take and PillAI builds your daily plan.',
    'أضف أدويتك وسيرتّب لك PillAI جدول يومك.',
  );
  String get addMedicine => _t('Add a medicine', 'أضف دواء');
  String get trySamplePlan => _t('Try a sample plan', 'جرّب خطة تجريبية');
  String get noDosesThisDay =>
      _t('No doses on this day', 'لا توجد جرعات في هذا اليوم');
  String progress(int done, int total) =>
      _t('$done of $total', '$done من $total');
  String get loggableLater =>
      _t('You can log this when it’s time.', 'يمكنك التسجيل عند حلول الموعد.');
  String takenSnack(String name) =>
      _t('${isolate(name)} marked as taken', 'تم تسجيل ${isolate(name)}');
  String get snoozedSnack =>
      _t('We’ll remind you in 10 minutes', 'سنذكّرك بعد 10 دقائق');
  String get missedSnack =>
      _t('Missed dose recorded', 'تم تسجيل الجرعة الفائتة');
  String get undoneSnack => _t('Change undone', 'تم التراجع');

  // ---------------------------------------------------------------------------
  // Dose details

  String get iTookIt => _t('I took it', 'أخذتها');
  String get remindIn10 => _t('Remind me in 10 min', 'ذكّرني بعد 10 دقائق');
  String get iMissedIt => _t('I missed it', 'فاتتني');
  String get undoRecord => _t('Undo', 'تراجع عن التسجيل');
  String get askAboutIt => _t('Ask PillAI about it', 'اسأل PillAI عنه');
  String takenAt(DateTime at) => _t('Taken ${time(at)}', 'أُخذت ${time(at)}');
  String get statusMissed => _t('Missed', 'فائتة');
  String get statusSnoozed => _t('Snoozed', 'مؤجلة');
  String get statusChanged => _t('Time changed', 'وقت معدّل');
  String originally(DateTime at) =>
      _t('Originally ${time(at)}', 'كانت ${time(at)}');
  String askAboutPrompt(String name) => _t('About $name: ', 'بخصوص $name: ');

  // Missed dose
  String get whyMissed => _t('What happened?', 'ما الذي حدث؟');
  String get reasonAsleep => _t('I was asleep', 'كنت نائماً');
  String get reasonForgot => _t('I forgot', 'نسيت');
  String get reasonAway => _t('I was away', 'كنت خارج المنزل');
  String get reasonUnwell => _t('I felt unwell', 'كنت متعباً');
  String get reasonRanOut => _t('I ran out', 'نفد الدواء');
  String get noDoubleDose => _t(
    'Don’t double your next dose unless your label or doctor says so.',
    'لا تضاعف الجرعة التالية إلا إذا نصّت النشرة أو الطبيب على ذلك.',
  );
  String get recordMissed => _t('Record missed dose', 'تسجيل الجرعة الفائتة');
  String get missedRecordedTitle => _t('Recorded', 'تم التسجيل');
  String get missedRecordedBody => _t(
    'Your reminders were not moved. Check the leaflet or ask a pharmacist before taking this dose late.',
    'لم نغيّر مواعيدك. راجع النشرة أو اسأل الصيدلي قبل أخذ هذه الجرعة متأخرة.',
  );
  String get askPillAi => _t('Ask PillAI', 'اسأل PillAI');
  String missedPrompt(String name, String reason) => _t(
    'I missed my $name dose ($reason). What should I do?',
    'فاتتني جرعة $name ($reason). ماذا أفعل؟',
  );

  // Reschedule proposals
  String reviewChanges(int n) => n == 1
      ? _t('Review reminder change', 'مراجعة تعديل الموعد')
      : _t('Review $n reminder changes', 'مراجعة $n تعديلات');
  String get applyChanges => _t('Apply changes', 'تطبيق التعديلات');
  String get keepCurrentTimes =>
      _t('Keep current times', 'إبقاء المواعيد الحالية');
  String get remindersUpdated => _t('Reminders updated', 'تم تحديث المواعيد');

  // ---------------------------------------------------------------------------
  // Assistant

  String get statusReady => _t('Knows your plan', 'يعرف خطتك');
  String get statusSmart => _t('Smart answers on', 'الإجابات الذكية مفعّلة');
  String get statusOffline => _t('Offline mode', 'الوضع المحلي');
  String get statusUnreachable =>
      _t('Offline answers right now', 'إجابات محلية حالياً');
  String get assistantEmptyTitle => _t('How can I help?', 'كيف أساعدك؟');
  String get assistantEmptyBody => _t(
    'Ask anything, or tell me what happened today.',
    'اسألني أي شيء، أو أخبرني بما حدث اليوم.',
  );

  /// (chip label, message sent) pairs.
  List<(String, String)> get suggestions => isArabic
      ? const [
          ('شربت شاي الحين', 'شربت شاي الحين، هل يأثر على أي جرعة اليوم؟'),
          ('نسيت جرعة', 'نسيت جرعة، وش أسوي؟'),
          ('أقدر آخذ أدويتي مع بعض؟', 'أقدر آخذ أدويتي مع بعض؟'),
          ('رتّب لي يومي', 'رتّب لي جرعات اليوم حسب وجباتي ونومي.'),
        ]
      : const [
          (
            'I just had tea',
            'I just drank tea. Does it affect any dose today?',
          ),
          ('I missed a dose', 'I missed a dose. What should I do?'),
          ('Can I take them together?', 'Can I take my medicines together?'),
          (
            'Organize my day',
            'Help me organize today’s doses around my meals and sleep.',
          ),
        ];

  String get composerHint => _t('Message PillAI…', 'اكتب رسالتك…');
  String get listening => _t(
    'Listening… check the text before sending',
    'أستمع… راجع النص قبل الإرسال',
  );
  String get stop => _t('Stop', 'إيقاف');
  String get retry => _t('Retry', 'إعادة');
  String get cancelVoice => _t('Cancel voice input', 'إلغاء الإدخال الصوتي');
  String get speak => _t('Speak', 'تحدّث');
  String get sendMessage => _t('Send message', 'إرسال');
  String get emergency => _t('Emergency', 'طوارئ');
  String get moreOptions => _t('More options', 'خيارات أخرى');
  String get newChat => _t('New chat', 'محادثة جديدة');
  String get aboutAndPrivacy => _t('About & privacy', 'عن المساعد والخصوصية');
  String get tooLong => _t(
    'Shorten your message to 2,000 characters or fewer.',
    'اختصر رسالتك إلى 2000 حرف أو أقل.',
  );
  String get sources => _t('Sources', 'المصادر');
  String get details => _t('Details', 'التفاصيل');
  String get openToday => _t('Open today’s plan', 'افتح جدول اليوم');
  String get openHealthProfile => _t('Open health profile', 'افتح ملفي الصحي');
  String get openMedicines => _t('Open my medicines', 'افتح أدويتي');

  String provenanceLive(String model) => 'PillAI · $model';
  String get provenanceOffline => _t('Offline answer', 'إجابة محلية');
  String get provenanceOfflineChoice =>
      _t('Offline · your choice', 'محلي · اختيارك');
  String get provenanceEmergency => _t('Emergency route', 'مسار الطوارئ');
  String get provenanceSafety => _t('Safety check', 'فحص السلامة');

  // Consent
  String get consentTitle =>
      _t('Turn on smart answers?', 'تفعيل الإجابات الذكية؟');
  String get consentPoint1 => _t(
    'To answer, PillAI sends your medicines, today’s plan and health notes to its server and its AI provider (OpenAI) — never your name.',
    'للإجابة، يرسل PillAI أدويتك وجدول اليوم وملاحظاتك الصحية إلى خادمه ومزوّد الذكاء الاصطناعي (OpenAI) — دون اسمك.',
  );
  String get consentPoint2 => _t(
    'AI can make mistakes and never changes your dose. Your pharmacist and doctor have the final word.',
    'الذكاء الاصطناعي قد يخطئ ولا يغيّر جرعتك أبداً، والكلمة الأخيرة لصيدليّك وطبيبك.',
  );
  String get consentPoint3 => _t(
    'You can turn this off anytime in Profile.',
    'يمكنك إيقافها في أي وقت من صفحة حسابي.',
  );
  String get consentAgree => _t('Turn on', 'تفعيل');
  String get consentOffline => _t('Use offline mode', 'استخدام الوضع المحلي');

  // Voice
  String get voiceTitle => _t('Use your voice?', 'استخدام الصوت؟');
  String get voiceBody => _t(
    'Your phone turns speech into text. You’ll see the text before anything is sent.',
    'يحوّل هاتفك كلامك إلى نص، وتراجعه قبل إرساله.',
  );

  // ---------------------------------------------------------------------------
  // Emergency

  String get emergencyTitle => _t('Is this an emergency?', 'هل هي حالة طارئة؟');
  String get emergencyBody => _t(
    'Too much medicine, trouble breathing, swelling or fainting — call now. Don’t wait for the app.',
    'جرعة زائدة، صعوبة في التنفس، تورّم أو إغماء — اتصل الآن ولا تنتظر التطبيق.',
  );
  String get callAmbulance => _t('Call 997 · Ambulance', 'اتصل 997 · الإسعاف');
  String get callEmergency => _t('Call 911 · Emergency', 'اتصل 911 · الطوارئ');
  String get callMoh =>
      _t('937 · Ministry of Health advice', '937 · استشارات وزارة الصحة');
  String get keepPackages => _t(
    'If you can, keep the medicine packages with you.',
    'إن أمكن، احتفظ بعلب الأدوية معك.',
  );
  String callFailed(String number) => _t(
    'Couldn’t open the phone app. Dial $number directly.',
    'تعذّر فتح الاتصال. اتصل على $number مباشرة.',
  );

  // ---------------------------------------------------------------------------
  // Medicines

  String get medicinesTitle => _t('Medicines', 'أدويتي');
  String get add => _t('Add', 'إضافة');
  String get noMedicinesTitle => _t('No medicines yet', 'لا توجد أدوية بعد');

  String timesPerDay(int n) => switch (n) {
    0 => _t('As needed', 'عند الحاجة'),
    1 => _t('Once a day', 'مرة يومياً'),
    2 => _t('Twice a day', 'مرتين يومياً'),
    _ => _t('$n times a day', '$n مرات يومياً'),
  };

  String get ongoing => _t('Ongoing', 'مستمر');
  String daysLeft(int n) => n <= 0
      ? _t('Course finished', 'انتهى العلاج')
      : isArabic
      ? 'باقي ${_count(n, en: '', enPlural: '', arOne: 'يوم', arTwo: 'يومان', arFew: 'أيام', arMany: 'يوماً')}'
      : '$n ${n == 1 ? 'day' : 'days'} left';
  String days(int n) => _count(
    n,
    en: 'day',
    enPlural: 'days',
    arOne: 'يوم واحد',
    arTwo: 'يومان',
    arFew: 'أيام',
    arMany: 'يوماً',
  );
  String medicineCount(int n) => _count(
    n,
    en: 'medicine',
    enPlural: 'medicines',
    arOne: 'دواء واحد',
    arTwo: 'دواءان',
    arFew: 'أدوية',
    arMany: 'دواءً',
  );
  String get prescription => _t('Prescription', 'وصفة طبية');
  String get times => _t('Times', 'المواعيد');
  String get course => _t('Course', 'مدة العلاج');
  String get instructions => _t('Instructions', 'التعليمات');
  String get activeIngredients => _t('Active ingredients', 'المواد الفعالة');
  String deleteMedicineTitle(String name) =>
      _t('Delete ${isolate(name)}?', 'حذف ${isolate(name)}؟');
  String get deleteMedicineBody => _t(
    'Its reminders and history will be removed.',
    'ستُحذف مواعيده وسجلّه.',
  );
  String until(DateTime date) =>
      _t('Until ${monthDay(date)}', 'حتى ${monthDay(date)}');

  String formLabel(MedicationForm form) => switch (form) {
    MedicationForm.tablet => _t('Tablet', 'حبوب'),
    MedicationForm.capsule => _t('Capsule', 'كبسولة'),
    MedicationForm.liquid => _t('Liquid', 'شراب'),
    MedicationForm.injection => _t('Injection', 'إبرة'),
    MedicationForm.other => _t('Other', 'أخرى'),
  };

  String defaultDose(MedicationForm form) => switch (form) {
    MedicationForm.tablet => _t('1 tablet', 'حبة واحدة'),
    MedicationForm.capsule => _t('1 capsule', 'كبسولة واحدة'),
    MedicationForm.liquid => _t('5 ml', '5 مل'),
    MedicationForm.injection => _t('1 injection', 'إبرة واحدة'),
    MedicationForm.other => _t('1 dose', 'جرعة واحدة'),
  };

  // Add / edit
  String get addMedicineTitle => _t('Add medicine', 'إضافة دواء');
  String get editMedicineTitle => _t('Edit medicine', 'تعديل الدواء');
  String get medicineName => _t('Medicine name', 'اسم الدواء');
  String get medicineNameHint => _t('e.g. Panadol', 'مثال: بنادول');
  String get medicineNameRequired =>
      _t('Enter the medicine name', 'اكتب اسم الدواء');
  String get type => _t('Type', 'النوع');
  String get dose => _t('Dose', 'الجرعة');
  String get doseRequired =>
      _t('Enter the dose on the label', 'اكتب الجرعة المكتوبة على العلبة');
  String get howOften => _t('How often?', 'كم مرة في اليوم؟');
  String get reminderTimes => _t('Reminder times', 'أوقات التذكير');
  String get forHowLong => _t('For how long?', 'مدة العلاج');
  String get moreDetails =>
      _t('More details (optional)', 'تفاصيل إضافية (اختياري)');
  String get strength => _t('Strength', 'التركيز');
  String get strengthHint => _t('e.g. 500 mg', 'مثال: 500 ملغ');
  String get ingredientsHint => _t('Separate with commas', 'افصل بينها بفاصلة');
  String get instructionsHint => _t('e.g. after food', 'مثال: بعد الأكل');
  String get prescribedByDoctor =>
      _t('Prescribed by a doctor', 'موصوف من طبيب');
  String get addToPlan => _t('Add to my plan', 'أضف إلى خطتي');
  String get saveChanges => _t('Save changes', 'حفظ التعديلات');
  String addedSnack(String name) => _t(
    '${isolate(name)} added to your plan',
    'تمت إضافة ${isolate(name)} إلى خطتك',
  );
  String get defaultInstructions =>
      _t('Follow the medicine label', 'اتبع تعليمات العلبة');
  String get tooManyIngredients =>
      _t('Add no more than 12 ingredients', 'أضف 12 مادة كحد أقصى');

  // ---------------------------------------------------------------------------
  // Profile

  String get profileTitle => _t('Profile', 'حسابي');
  String get sectionHealth => _t('Health', 'الصحة');
  String get sectionApp => _t('App', 'التطبيق');
  String get sectionPrivacy => _t('Privacy & safety', 'الخصوصية والأمان');
  String get healthProfile => _t('Health profile', 'ملفي الصحي');
  String get dailyRoutine => _t('Daily routine', 'روتيني اليومي');
  String get wakeUp => _t('Wake up', 'الاستيقاظ');
  String get sleep => _t('Sleep', 'النوم');
  String get languageLabel => _t('Language', 'اللغة');
  String languageName(AppLanguage value) =>
      value == AppLanguage.arabic ? 'العربية' : 'English';
  String get simpleMode => _t('Large & simple mode', 'الوضع المبسّط');
  String get simpleModeHint => _t('Bigger text and buttons', 'خط وأزرار أكبر');
  String get smartAnswers => _t('Smart answers', 'الإجابات الذكية');
  String get askMe => _t('Ask me', 'اسألني');
  String get howPillAiKeepsYouSafe =>
      _t('How PillAI keeps you safe', 'كيف يحميك PillAI');
  List<String> get safetyPromises => isArabic
      ? const [
          'ينظّم أدويتك ويشرح لك — لا يشخّص ولا يصف علاجاً.',
          'لا يغيّر جرعتك ولا عدد مرات أخذها أبداً.',
          'أي تغيير في المواعيد يحتاج موافقتك.',
          'الذكاء الاصطناعي قد يخطئ، والكلمة الأخيرة لصيدليّك وطبيبك.',
          'بياناتك تبقى على هاتفك إلا إذا فعّلت الإجابات الذكية.',
          'PillAI ليس جهازاً طبياً، ولا يشخّص أو يعالج أو يشفي أو يمنع أي حالة طبية.',
        ]
      : const [
          'It organizes and explains — it doesn’t diagnose or prescribe.',
          'It never changes your dose or how often you take it.',
          'Any time change needs your approval.',
          'AI can make mistakes. Your pharmacist and doctor have the final word.',
          'Your data stays on this phone unless you turn on smart answers.',
          'PillAI is not a medical device and does not diagnose, treat, cure, or prevent any medical condition.',
        ];
  String get emergencyNumbers => _t('Emergency numbers', 'أرقام الطوارئ');
  String get deleteAllData => _t('Delete all my data', 'حذف كل بياناتي');
  String get deleteAllDataBody => _t(
    'This permanently removes your medicines, history and chats from this phone.',
    'سيتم حذف أدويتك وسجلّك ومحادثاتك من هذا الهاتف نهائياً.',
  );
  String get yourName => _t('Your name', 'اسمك');
  String get smartAnswersBody => _t(
    'When on, your medicines, today’s plan and health notes are sent to PillAI’s server and its AI provider (OpenAI) to answer you. Your name is never sent.',
    'عند التفعيل، تُرسل أدويتك وجدول اليوم وملاحظاتك الصحية إلى خادم PillAI ومزوّد الذكاء الاصطناعي (OpenAI) للإجابة عليك، ولا يُرسل اسمك أبداً.',
  );

  // ---------------------------------------------------------------------------
  // Health profile

  String healthProgress(int n, int total) =>
      _t('$n of $total done', 'أكملت $n من $total');
  String get healthWhy =>
      _t('Helps PillAI answer safely.', 'يساعد PillAI على إجابات أكثر أماناً.');
  String get continueSetup => _t('Continue', 'أكمل');
  String get groupBody => _t('Body & health', 'الجسم والصحة');
  String get groupDaily => _t('Daily life', 'الحياة اليومية');
  String get groupSupport => _t('Support', 'الدعم');
  String get ageAndWeight => _t('Age & weight', 'العمر والوزن');
  String get pregnancy => _t('Pregnancy & breastfeeding', 'الحمل والرضاعة');
  String get kidneys => _t('Kidneys', 'الكلى');
  String get liver => _t('Liver', 'الكبد');
  String get conditions => _t('Health conditions', 'الحالات الصحية');
  String get allergies => _t('Allergies', 'الحساسية');
  String get foodAndDrinks => _t('Food & drinks', 'الأكل والمشروبات');
  String get supplements =>
      _t('Supplements & OTC', 'المكملات والأدوية بدون وصفة');
  String get lifestyle => _t('Lifestyle', 'نمط الحياة');
  String get accessibility =>
      _t('Accessibility & caregiver', 'سهولة الاستخدام والمرافق');
  String get notSet => _t('Not set', 'غير محدد');
  String get noneRecorded => _t('None', 'لا يوجد');
  String get noneSelected => _t('None selected', 'لا شيء');
  String andMore(String first, int more) => '$first +$more';
  String get noKnownIssue => _t('No known problem', 'لا توجد مشكلة معروفة');
  String get hasCondition => _t('Has a condition', 'توجد حالة');
  String get notSure => _t('Not sure', 'غير متأكد');
  String get kidneyYes =>
      _t('Kidney disease, dialysis or transplant', 'مرض كلى أو غسيل أو زراعة');
  String get liverYes => _t('Liver disease or transplant', 'مرض كبد أو زراعة');
  String get ageRange => _t('Age range', 'الفئة العمرية');
  String get weightOptional => _t('Weight (optional)', 'الوزن (اختياري)');
  String get weightHint => _t('e.g. 72 kg', 'مثال: 72 كغ');
  String get sexOptional => _t('Sex (optional)', 'الجنس (اختياري)');
  String get conditionsHint =>
      _t('e.g. diabetes, high blood pressure', 'مثال: سكري، ضغط');
  String get allergiesHint =>
      _t('e.g. penicillin – rash', 'مثال: بنسلين – طفح جلدي');
  String get separateWithCommas =>
      _t('Separate with commas', 'افصل بينها بفاصلة');
  String saveSelected(int n) => _t('Save ($n)', 'حفظ ($n)');
  String get noneApply => _t('None apply', 'لا ينطبق شيء');

  String reproductiveLabel(ReproductiveStatus value) => switch (value) {
    ReproductiveStatus.notAnswered => notSet,
    ReproductiveStatus.notApplicable => _t('Not applicable', 'لا ينطبق'),
    ReproductiveStatus.pregnant => _t('Pregnant', 'حامل'),
    ReproductiveStatus.breastfeeding => _t('Breastfeeding', 'مرضع'),
    ReproductiveStatus.tryingToConceive => _t(
      'Trying to conceive',
      'أحاول الحمل',
    ),
    ReproductiveStatus.postpartum => _t('Recently gave birth', 'وضعت مؤخراً'),
    ReproductiveStatus.none => _t('None of these', 'لا شيء مما سبق'),
    ReproductiveStatus.preferNotToAnswer => _t(
      'Prefer not to say',
      'أفضّل عدم الإجابة',
    ),
  };

  String organLabel(ProfileAnswer value, {required bool kidney}) =>
      switch (value) {
        ProfileAnswer.notAnswered => notSet,
        ProfileAnswer.no => noKnownIssue,
        ProfileAnswer.yes => kidney ? kidneyYes : liverYes,
        ProfileAnswer.unsure => notSure,
      };

  /// Stored values stay English so the backend sees one vocabulary.
  String storedValue(String value) {
    if (!isArabic) return value;
    return ArabicLabels.of(value);
  }

  // ---------------------------------------------------------------------------
  // Onboarding

  String get tagline => _t(
    'Your medicines, organized.\nYour day, easier.',
    'أدويتك مرتّبة،\nويومك أسهل.',
  );
  String get chooseLanguage => _t('Choose your language', 'اختر لغتك');
  String get getStarted => _t('Get started', 'ابدأ');
  String get whatsYourName => _t('What should we call you?', 'ما اسمك؟');
  String get nameOptional => _t('Your name (optional)', 'اسمك (اختياري)');
  String get promisePlan =>
      _t('A clear plan for every day', 'جدول واضح لكل يوم');
  String get promiseAi => _t(
    'Tell PillAI what happened — it updates your day',
    'أخبر PillAI بما حدث — وسيحدّث يومك',
  );
  String get promiseDose =>
      _t('It never changes your dose', 'لا يغيّر جرعتك أبداً');
  String get onboardingDisclaimer => _t(
    'PillAI organizes your medicines. It is not a doctor or a medical device. In an emergency call 997.',
    'PillAI ينظّم أدويتك، وليس طبيباً ولا جهازاً طبياً. في الطوارئ اتصل على 997.',
  );
  String get agreeAndStart => _t('Agree & start', 'موافق، لنبدأ');
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'en' || locale.languageCode == 'ar';

  @override
  Future<AppStrings> load(Locale locale) {
    return SynchronousFuture(
      AppStrings(
        locale.languageCode == 'ar' ? AppLanguage.arabic : AppLanguage.english,
      ),
    );
  }

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}
