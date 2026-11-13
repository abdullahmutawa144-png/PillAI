import 'app_models.dart';
import 'app_store.dart';
import 'arabic_labels.dart';

/// A deterministic offline assistant.
///
/// This engine deliberately routes broad safety categories without attempting
/// to calculate doses, interaction severity, or medicine-specific intervals.
/// Those decisions require verified product data and clinical rules that are
/// outside its coverage. It answers in Arabic when the message is Arabic.
class DemoAssistantEngine {
  const DemoAssistantEngine();

  static const List<String> _emergencyTerms = [
    'overdose',
    'overdosed',
    'too many pills',
    'too much medicine',
    'double dose',
    'double dosed',
    'extra dose',
    'took extra',
    'wrong medicine',
    'wrong medication',
    'wrong patient',
    'child swallowed',
    'child took medicine',
    'cannot breathe',
    "can't breathe",
    'cant breathe',
    'difficulty breathing',
    'trouble breathing',
    'shortness of breath',
    'face swelling',
    'facial swelling',
    'tongue swelling',
    'tongue is swelling',
    'swollen tongue',
    'throat swelling',
    'throat is swelling',
    'swollen throat',
    'lip swelling',
    'lips swelling',
    'lips are swelling',
    'anaphylaxis',
    'severe allergic reaction',
    'having a seizure',
    'seizing',
    'unconscious',
    'unresponsive',
    'passed out',
    'collapsed',
    'not waking',
    'chest pain',
    'stroke symptoms',
    'face drooping',
    'face is drooping',
    'slurred speech',
    'speech is slurred',
    'sudden one sided weakness',
    'vomiting blood',
    'coughing blood',
    'black stool',
    'severe bleeding',
    'bleeding will not stop',
    'blood in stool',
    'blistering rash',
    'peeling skin',
    'rash in my mouth',
    'rash in my eyes',
    'intentional overdose',
    'hurt myself',
    'kill myself',
    'end my life',
    // High-signal Arabic phrases, including common Saudi wording. This finite
    // list is a safety backstop, not comprehensive multilingual triage.
    'جرعة زائدة',
    'جرعة اضافية',
    'جرعة كبيرة',
    'اخذت جرعة اضافية',
    'تناولت جرعة زائدة',
    'بلع حبوب',
    'بلع الدواء',
    'طفل بلع',
    'شرب الدواء كله',
    'لا استطيع التنفس',
    'ما اقدر اتنفس',
    'مو قادر اتنفس',
    'صعوبة في التنفس',
    'ضيق تنفس شديد',
    'اختناق',
    'تورم الوجه',
    'وجهي متورم',
    'تورم اللسان',
    'تورم في اللسان',
    'لساني متورم',
    'تورم الحلق',
    'حلقي متورم',
    'تورم الشفاه',
    'فاقد الوعي',
    'فقدت الوعي',
    'اغمي عليه',
    'مغمى عليه',
    'لا يستجيب',
    'ما يستجيب',
    'نوبة صرع',
    'تشنجات',
    'تشنج',
    'الم في الصدر',
    'بالم في الصدر',
    'نزيف شديد',
    'النزيف ما وقف',
    'اتقيا دما',
    'استفرغ دم',
    'اريد قتل نفسي',
    'ابي اموت',
    'ابغى اموت',
    'انهي حياتي',
    'انتحار',
  ];

  static const List<String> _missedDoseTerms = [
    'missed',
    'forgot',
    'slept through',
    'late dose',
    'dose is late',
    'نسيت',
    'فاتتني',
    'فاتني',
    'فوت',
    'ما اخذت',
    'لم اخذ',
    'لم اتناول',
    'نمت عن',
    'تاخرت عن',
  ];

  static const List<String> _takenDoseTerms = [
    'mark as taken',
    'record as taken',
    'log as taken',
    'mark my dose taken',
    'record my dose',
    'log my dose',
    'dose is done',
    'took my scheduled dose',
    'already took my medicine',
    'have taken my medicine',
    'اخذت دوائي',
    'اخذت الدواء',
    'اخذت الجرعة',
    'تناولت دوائي',
    'سجل اني اخذت',
  ];

  static const List<String> _reproductiveTerms = [
    'pregnant',
    'pregnancy',
    'expecting a baby',
    'breastfeeding',
    'breast feeding',
    'nursing a baby',
    'trying to conceive',
    'trying for a baby',
    'postpartum',
    'حامل',
    'الحمل',
    'رضاعة',
    'ارضع',
    'مرضع',
    'ولادة',
  ];

  static const List<String> _kidneyTerms = [
    'kidney',
    'kidneys',
    'kidney disease',
    'renal disease',
    'renal failure',
    'dialysis',
    'creatinine',
    'الكلى',
    'كليتي',
    'غسيل كلوي',
    'الكلوي',
  ];

  static const List<String> _liverTerms = [
    'liver',
    'liver disease',
    'hepatic disease',
    'cirrhosis',
    'hepatitis',
    'كبد',
    'تليف',
  ];

  static const List<String> _allergyTerms = [
    'allergy',
    'allergies',
    'allergic',
    'hives',
    'itchy rash',
    'medicine rash',
    'drug reaction',
    'حساسية',
    'تحسس',
    'طفح',
    'حكة',
  ];

  static const List<String> _conditionTerms = [
    'diabetes',
    'heart disease',
    'heart condition',
    'arrhythmia',
    'high blood pressure',
    'hypertension',
    'low blood pressure',
    'bleeding disorder',
    'clotting disorder',
    'stomach ulcer',
    'peptic ulcer',
    'thyroid disease',
    'epilepsy',
    'seizure disorder',
    'asthma',
    'copd',
    'sleep apnea',
    'glaucoma',
    'urinary retention',
    'organ transplant',
    'immunosuppressed',
    'swallowing difficulty',
    'سكري',
    'مرض السكر',
    'ضغط',
    'القلب',
    'قلبي',
    'ربو',
    'صرع',
    'الغدة',
    'قرحة',
    'القولون',
  ];

  static const List<String> _duplicateIngredientTerms = [
    'duplicate ingredient',
    'duplicate ingredients',
    'duplicate active ingredient',
    'duplicate active ingredients',
    'same ingredient',
    'same active ingredient',
    'double ingredient',
    'combination product',
    'two cold medicines',
    'two flu medicines',
    'نفس المادة',
    'نفس المكون',
    'مادة مكررة',
  ];

  static const List<String> _foodAndDrinkTerms = [
    'food',
    'meal',
    'with breakfast',
    'with lunch',
    'with dinner',
    'empty stomach',
    'fasting',
    'milk',
    'dairy',
    'calcium rich food',
    'tea',
    'coffee',
    'caffeine',
    'grapefruit',
    'pomelo',
    'alcohol',
    'juice',
    'leafy greens',
    'vitamin k food',
    'potassium food',
    'salt substitute',
    'fermented food',
    'high fiber',
    'tube feeding',
    'شاي',
    'قهوة',
    'حليب',
    'لبن',
    'البان',
    'الاكل',
    'اكلت',
    'وجبة',
    'سحور',
    'افطار',
    'فطور',
    'غداء',
    'عشاء',
    'صيام',
    'صايم',
    'معدة فاضية',
    'جريب فروت',
    'عصير',
    'كافيين',
  ];

  static const List<String> _supplementAndOtcTerms = [
    'otc',
    'over the counter',
    'supplement',
    'multivitamin',
    'vitamin supplement',
    'herbal',
    'natural product',
    "st john's wort",
    'iron',
    'calcium',
    'magnesium',
    'zinc',
    'antacid',
    'pain reliever',
    'painkiller',
    'ibuprofen',
    'naproxen',
    'aspirin',
    'paracetamol',
    'acetaminophen',
    'cold medicine',
    'flu medicine',
    'cough syrup',
    'sleep aid',
    'مكمل',
    'فيتامين',
    'حديد',
    'كالسيوم',
    'مغنيسيوم',
    'زنك',
    'اعشاب',
    'مسكن',
    'بنادول',
    'باراسيتامول',
    'بروفين',
    'اسبرين',
    'مضاد حموضة',
  ];

  static const List<String> _interactionTerms = [
    'interaction',
    'interact',
    'together',
    'same time',
    'combine',
    'mix medicines',
    'mix medications',
    'take both',
    'take these',
    'مع بعض',
    'تداخل',
    'تتداخل',
    'تعارض',
    'يتعارض',
    'نفس الوقت',
  ];

  static const List<String> _scheduleTerms = [
    'schedule',
    'organize',
    'organise',
    'plan today',
    "today's plan",
    'plan my medicine',
    'plan my medication',
    'next dose',
    'what is due',
    'how many doses',
    'reminder time',
    'جدول',
    'رتب',
    'نظم',
    'موعد',
    'مواعيد',
    'الجرعة القادمة',
  ];

  static const List<String> _sideEffectTerms = [
    'side effect',
    'symptom',
    'feel sick',
    'feeling sick',
    'nausea',
    'dizzy',
    'dizziness',
    'headache',
    'stomach pain',
    'new pain',
    'اعراض',
    'عرض جانبي',
    'اثار جانبية',
    'دوخة',
    'دايخ',
    'غثيان',
    'صداع',
    'وجع',
    'تعبان',
    'استفراغ',
  ];

  static const List<String> _coverageTerms = [
    'what can you check',
    'what do you check',
    'what do you know',
    'what is saved',
    'your coverage',
    'your limitations',
    'what are your limits',
    'how do you work',
    'can you verify',
    'verified database',
    'وش تقدر',
    'ماذا تستطيع',
    'كيف تشتغل',
    'حدودك',
  ];

  static const List<String> _vagueSafetyTerms = [
    'is this safe',
    'is it safe',
    'is this okay',
    'is it okay',
    'can i take this',
    'can i take it',
    'this medicine',
    'this medication',
    'what dosage',
    'how much should i take',
    'should i stop',
    'should i start',
    'when should i take it',
    'هل هو امن',
    'هل امن',
    'اقدر اخذه',
    'كم اخذ',
    'كم جرعة',
    'اوقف الدواء',
  ];

  AssistantReply replyTo(String prompt, AppStore store) {
    final String text = _normalize(prompt);
    final bool ar = _replyInArabic(prompt, store);

    if (_containsAny(text, _emergencyTerms)) {
      return ar
          ? const AssistantReply(
              title: 'اطلب المساعدة الآن',
              message:
                  'الجرعة الزائدة أو التحسس الشديد أو أعراض الطوارئ قد تحتاج تدخلاً فورياً. اتصل الآن على 997 (الإسعاف) أو 911 ولا تنتظر التطبيق. إن أمكن، احتفظ بعلب الأدوية وأوقات الجرعات.',
              level: SafetyLevel.urgent,
              actionLabel: 'View emergency guidance',
              coverage: SafetyCoverage.generalGuidance,
              contextNote:
                  'التقط PillAI كلمات تحذيرية فقط، ولم يشخّص الحالة أو يتحقق مما حدث.',
            )
          : const AssistantReply(
              title: 'Get urgent help now',
              message:
                  'An overdose, extra dose, severe reaction, or emergency symptom may need immediate help. In Saudi Arabia call 997 (ambulance) or 911 now and do not wait for this app. If it is safe, bring the medicine packages and the times each dose was taken.',
              level: SafetyLevel.urgent,
              actionLabel: 'View emergency guidance',
              coverage: SafetyCoverage.generalGuidance,
              contextNote:
                  'PillAI detected emergency warning words only; it did not diagnose or verify what happened.',
            );
    }

    if (_containsAny(text, _missedDoseTerms)) {
      return ar
          ? const AssistantReply(
              title: 'لنتعامل مع الجرعة الفائتة بأمان',
              message:
                  'سجّل الجرعة كفائتة من جدول اليوم. لا تضاعف الجرعة التالية إلا إذا نصّت النشرة أو الطبيب على ذلك. التصرف الصحيح يعتمد على الدواء وكم تأخرت.',
              level: SafetyLevel.caution,
              actionLabel: "Open today's doses",
              suggestedPrompt: 'أي دواء فاتك، ومتى كان موعده؟',
              coverage: SafetyCoverage.notChecked,
              contextNote:
                  'لم يتم التحقق من تعليمات الجرعة الفائتة الخاصة بهذا الدواء.',
            )
          : const AssistantReply(
              title: "Let's handle the missed dose safely",
              message:
                  'Record the dose as missed, then I can show a reminder-plan preview. Do not double the next dose unless the medicine label or your clinician specifically tells you to. Exact advice depends on the medicine and how late it is.',
              level: SafetyLevel.caution,
              actionLabel: "Open today's doses",
              suggestedPrompt:
                  'Which medicine did you miss and when was it due?',
              coverage: SafetyCoverage.notChecked,
              contextNote:
                  'No medicine-specific missed-dose instruction was checked.',
            );
    }

    if (_containsAny(text, _takenDoseTerms)) {
      return ar
          ? const AssistantReply(
              title: 'سجّل الجرعة التي أخذتها',
              message:
                  'افتح جدول اليوم واضغط «أخذتها» بجانب الدواء. التسجيل يحفظ الوقت فقط ولا يعني أن الجرعة أو توقيتها مناسب طبياً.',
              level: SafetyLevel.general,
              actionLabel: "Open today's doses",
              coverage: SafetyCoverage.generalGuidance,
              contextNote: 'هذا يحدّث السجل فقط؛ لم يتم فحص أي قاعدة دوائية.',
            )
          : const AssistantReply(
              title: 'Record the dose you took',
              message:
                  'Open today\'s doses and use Taken for the matching medicine. PillAI can save the actual dose time, but recording it does not confirm that the dose or timing was medically appropriate.',
              level: SafetyLevel.general,
              actionLabel: "Open today's doses",
              coverage: SafetyCoverage.generalGuidance,
              contextNote:
                  'This action updates the dose record only; no medicine safety rule was checked.',
            );
    }

    if (_containsAny(text, _reproductiveTerms)) {
      return AssistantReply(
        title: ar
            ? 'الحمل والرضاعة يحتاجان فحصاً خاصاً'
            : 'Pregnancy and breastfeeding need a specific check',
        message: ar
            ? 'الحمل ومحاولة الحمل وما بعد الولادة والرضاعة قد تغيّر قرار الدواء. نحتاج الاسم الدقيق والمادة الفعالة والتركيز والجرعة. لا تبدأ أو توقف أو تغيّر دواءً موصوفاً بناءً على هذه الإجابة فقط؛ راجع الصيدلي أو الطبيب.'
            : 'Pregnancy, trying to conceive, postpartum recovery, and breastfeeding can change medicine decisions. The exact product, active ingredient, strength, dose, and current situation are needed. This demo has not checked that product, so do not start, stop, or change a prescribed medicine based only on this answer; confirm with a pharmacist or prescriber.',
        level: SafetyLevel.caution,
        actionLabel: 'Review safety profile',
        suggestedPrompt: ar
            ? 'ما الاسم والتركيز المكتوبان على العلبة؟'
            : 'What is the exact name and strength printed on the package?',
        coverage: SafetyCoverage.notChecked,
        contextNote: _reproductiveContextNote(store.safetyContext, ar),
      );
    }

    final bool asksAboutKidneys = _containsAny(text, _kidneyTerms);
    final bool asksAboutLiver = _containsAny(text, _liverTerms);
    if (asksAboutKidneys || asksAboutLiver) {
      return AssistantReply(
        title: ar
            ? 'صحة الكلى أو الكبد قد تغيّر قرار الدواء'
            : 'Kidney or liver health can change medicine decisions',
        message: ar
            ? 'وظائف الكلى والكبد قد تؤثر على مناسبة الدواء أو جرعته، وأي تعديل يعتمد على الدواء نفسه. هذا الوضع لا يحسب الجرعات ولا يعدّلها. راجع الصيدلي أو الطبيب بالاسم والتركيز والتعليمات.'
            : 'Kidney and liver function can affect whether a medicine or dose is appropriate, but any adjustment is medicine-specific. This demo does not calculate or verify dose changes. Share the exact product, strength, prescribed directions, and relevant clinical advice with a pharmacist or prescriber before changing it.',
        level: SafetyLevel.caution,
        actionLabel: 'Review safety profile',
        suggestedPrompt: ar
            ? 'عن أي دواء وتركيز تسأل؟'
            : 'Which medicine and strength are you asking about?',
        coverage: SafetyCoverage.notChecked,
        contextNote: _organContextNote(
          store.safetyContext,
          includeKidney: asksAboutKidneys,
          includeLiver: asksAboutLiver,
          ar: ar,
        ),
      );
    }

    if (_containsAny(text, _allergyTerms)) {
      return AssistantReply(
        title: ar
            ? 'فحص الحساسية يحتاج المكونات الدقيقة'
            : 'An allergy check needs the exact ingredients',
        message: ar
            ? 'اسم الحساسية وحده لا يكفي للحكم على أمان المنتج لأن المكونات تختلف بين الأصناف. راجع المكونات الفعالة وغير الفعالة مع الصيدلي. عند صعوبة التنفس أو الإغماء أو تورم الوجه أو الشفاه أو اللسان أو الحلق، اتصل على 997 فوراً.'
            : 'A saved allergy name cannot by itself confirm whether a product is safe because brand names and inactive ingredients vary. Check the exact active and inactive ingredients with a pharmacist. For trouble breathing, fainting, or swelling of the face, lips, tongue, or throat, get emergency help now.',
        level: SafetyLevel.caution,
        actionLabel: 'Review medication list',
        suggestedPrompt: ar
            ? 'ما رد الفعل الذي حدث، ومتى بدأ، وما المنتج المستخدم؟'
            : 'What reaction happened, when did it start, and what exact product was used?',
        coverage: SafetyCoverage.notChecked,
        contextNote: _allergyContextNote(store.profile, ar),
      );
    }

    if (_containsAny(text, _conditionTerms)) {
      return AssistantReply(
        title: ar
            ? 'الحالات الصحية قد تغيّر احتياطات الدواء'
            : 'Health conditions can change medicine precautions',
        message: ar
            ? 'الحالة الصحية قد تؤثر على مناسبة الدواء أو جرعته أو الأدوية بدون وصفة، والقاعدة تعتمد على الحالة والمادة الفعالة. لم يتم فحص هذه التركيبة. لا تبدأ أو توقف أو تعدّل دواءً موصوفاً بناءً على هذه الإجابة؛ راجع الصيدلي أو الطبيب.'
            : 'A health condition can affect whether a medicine, dose, or over-the-counter product is appropriate, but the rule is specific to the condition and exact active ingredient. This demo has not checked that combination. Do not start, stop, or adjust a prescribed medicine from this answer; confirm with a pharmacist or prescriber.',
        level: SafetyLevel.caution,
        actionLabel: 'Review safety profile',
        suggestedPrompt: ar
            ? 'ما الحالة والدواء والتركيز والتعليمات؟'
            : 'Which condition, exact medicine, strength, and label directions are involved?',
        coverage: SafetyCoverage.notChecked,
        contextNote: _conditionContextNote(store.profile, ar),
      );
    }

    if (_containsAny(text, _duplicateIngredientTerms)) {
      return AssistantReply(
        title: ar
            ? 'تحقق من كل مادة فعالة قبل أخذهما معاً'
            : 'Check every active ingredient before taking both',
        message: ar
            ? 'أدوية البرد والإنفلونزا والمسكنات والمنومات قد تحتوي المادة الفعالة نفسها. لا تفترض أن اختلاف الاسم التجاري يعني اختلاف المكونات؛ تأكد من الأسماء والتراكيز والجرعات مع الصيدلي.'
            : 'Combination, cold, flu, pain, and sleep products can contain duplicate active ingredients. This demo cannot compare the labels or verify that the products are safe together. Do not assume different brand names mean different ingredients; confirm the exact ingredient names, strengths, and doses with a pharmacist.',
        level: SafetyLevel.caution,
        actionLabel: 'Review medication list',
        suggestedPrompt: ar
            ? 'اكتب كل مادة فعالة وتركيزها من العلبتين.'
            : 'List every active ingredient and strength shown on both labels.',
        coverage: SafetyCoverage.notChecked,
        contextNote: _supplementContextNote(store.safetyContext, ar),
      );
    }

    if (_containsAny(text, _foodAndDrinkTerms)) {
      return AssistantReply(
        title: ar
            ? 'توقيت الأكل والمشروبات يختلف حسب الدواء'
            : 'Food and drink timing is medicine-specific',
        message: ar
            ? 'الأكل والحليب والشاي والقهوة والجريب فروت والمعادن قد تؤثر على بعض الأدوية، لكن الأثر والمدة الفاصلة تختلف من دواء لآخر. تأكد من الاسم والتركيز وتعليمات النشرة قبل تغيير خطتك. هذا الوضع لا يستطيع التحقق من مدة آمنة ولن يخترعها.'
            : 'Food, milk, tea, coffee, grapefruit, alcohol, minerals, and meal timing can matter for selected medicines, but the effect and required spacing are medicine-specific. Confirm the exact product, strength, and label directions before changing your plan. This demo cannot verify a safe interval and will not invent one.',
        level: SafetyLevel.caution,
        actionLabel: 'Review medication list',
        suggestedPrompt: ar
            ? 'ما الدواء والتركيز والأكل أو المشروب وتعليمات النشرة؟'
            : 'What exact medicine, strength, food or drink, and label directions are involved?',
        coverage: SafetyCoverage.notChecked,
        contextNote: _foodContextNote(store.safetyContext, ar),
      );
    }

    if (_containsAny(text, _supplementAndOtcTerms)) {
      return AssistantReply(
        title: ar
            ? 'المكملات والأدوية بدون وصفة تدخل في الفحص'
            : 'OTC products and supplements count in safety checks',
        message: ar
            ? 'الأدوية بدون وصفة والفيتامينات والمعادن ومضادات الحموضة والأعشاب قد تتداخل أو تتكرر مكوناتها. نحتاج المواد الفعالة والتراكيز وأوقات الجرعات. هذا الوضع لا يستطيع التحقق من التركيبة أو اختراع مدة فاصلة.'
            : 'Non-prescription medicines, vitamins, minerals, antacids, herbs, and combination products can interact or duplicate ingredients. The exact active ingredients, strengths, and dose times are required. This demo cannot verify the combination or invent a spacing interval.',
        level: SafetyLevel.caution,
        actionLabel: 'Review medication list',
        suggestedPrompt: ar
            ? 'اكتب المواد الفعالة والتراكيز المكتوبة على كل منتج.'
            : 'List the active ingredients and strengths printed on every product.',
        coverage: SafetyCoverage.notChecked,
        contextNote: _supplementContextNote(store.safetyContext, ar),
      );
    }

    if (_containsAny(text, _interactionTerms)) {
      return AssistantReply(
        title: ar
            ? 'المكونات الدقيقة هي الأساس'
            : 'The exact ingredients matter',
        message: ar
            ? 'فحص التداخل يحتاج المواد الفعالة الدقيقة والتراكيز وتعليمات الجرعات والأدوية التي أُخذت. أي مدة فاصلة تعتمد على الدواء نفسه. هذا الوضع لا يستطيع التحقق من التركيبة أو من مدة آمنة.'
            : 'An interaction check needs the exact active ingredients, strengths, dose directions, and products already taken. Any required spacing is medicine-specific. This demo cannot verify the combination or a safe interval.',
        level: SafetyLevel.caution,
        actionLabel: 'Review medication list',
        suggestedPrompt: ar
            ? 'اكتب الأسماء والتراكيز المكتوبة على العلبتين.'
            : 'Tell me the exact names and strengths printed on both labels.',
        coverage: SafetyCoverage.notChecked,
        contextNote: _overallContextNote(store.safetyContext, ar),
      );
    }

    if (_containsAny(text, _scheduleTerms)) {
      final int remaining = store.todayDoses
          .where((dose) => dose.status != DoseStatus.taken)
          .length;
      return AssistantReply(
        title: ar ? 'يومك باختصار' : 'Your day at a glance',
        message: ar
            ? 'لديك $remaining من ${store.totalToday} جرعات لم تُسجّل بعد اليوم. يرتّب PillAI التذكيرات حول روتينك فقط بعد التحقق من تعليمات الوصفة وقواعد التداخل، ولا يغيّر الجرعة أو عدد المرات ولا يخترع مدة فاصلة.'
            : 'You have $remaining of ${store.totalToday} demo doses still open today. PillAI can arrange reminders around saved routines only after prescription directions and interaction rules are verified. It will not change the prescribed dose or frequency or invent a spacing rule.',
        level: SafetyLevel.general,
        actionLabel: 'View schedule',
        suggestedPrompt: ar
            ? 'حول أي وجبة أو روتين تريد التذكيرات؟'
            : 'Which meal or routine should the reminders fit around?',
        coverage: SafetyCoverage.generalGuidance,
        contextNote: ar
            ? 'الأعداد من خطتك المحفوظة؛ لم يتم فحص توقيت خاص بأي دواء.'
            : 'Dose counts come from the saved plan; no medicine-specific timing rule was checked.',
      );
    }

    if (_containsAny(text, _sideEffectTerms)) {
      return ar
          ? const AssistantReply(
              title: 'أحتاج تفاصيل أكثر عن العرض',
              message:
                  'اذكر الدواء والعرض ومتى بدأ وشدته وموعد الجرعة. لا يستطيع هذا الوضع تحديد إن كان الدواء هو السبب. عند صعوبة التنفس أو تورم الوجه أو الحلق أو الإغماء أو التشنج أو ألم الصدر أو الجرعة الزائدة، اتصل على 997 فوراً.',
              level: SafetyLevel.caution,
              suggestedPrompt: 'ما العرض، وأي دواء وجرعة سبقته؟',
              coverage: SafetyCoverage.insufficientInformation,
              contextNote: 'تقييم العرض يحتاج تفاصيل غير موجودة في رسالتك.',
            )
          : const AssistantReply(
              title: 'I need more detail about the symptom',
              message:
                  'Provide the exact medicine, symptom, when it started, how severe it is, and the dose time. This prototype cannot determine whether the medicine caused it. For trouble breathing, facial or throat swelling, fainting, seizure, chest pain, or suspected overdose, get emergency help now.',
              level: SafetyLevel.caution,
              suggestedPrompt:
                  'What symptom are you having, and which medicine and dose came before it?',
              coverage: SafetyCoverage.insufficientInformation,
              contextNote:
                  'A symptom assessment needs details that are not available in this message.',
            );
    }

    if (_containsAny(text, _coverageTerms)) {
      return AssistantReply(
        title: ar ? 'ما الذي يغطيه هذا الوضع' : 'What this prototype covers',
        message: ar
            ? 'في الوضع المحلي يستخدم PillAI قواعد ثابتة لالتقاط كلمات الطوارئ وحدود الجرعات الفائتة والمواضيع التي تحتاج مراجعة، ويقرأ جدولك وملفك الصحي. لا يملك بعد قاعدة بيانات موثقة للتداخلات أو فحصاً للحساسية أو جرعات خاصة بالحمل أو الكلى أو الكبد.'
            : 'PillAI currently uses deterministic wording rules to surface emergency phrases, missed-dose boundaries, and categories that need review. It can read saved dose status and profile context. It does not yet have a verified ingredient interaction database, allergy cross-checking, pregnancy or organ-specific dosing rules, or product-specific food intervals.',
        level: SafetyLevel.general,
        actionLabel: 'Review safety profile',
        suggestedPrompt: ar
            ? 'ما المعلومات الناقصة في ملفي الصحي؟'
            : 'Ask what information is still missing from your safety profile.',
        coverage: SafetyCoverage.generalGuidance,
        contextNote: _coverageContextNote(store.safetyContext, ar),
      );
    }

    if (text.isEmpty || _containsAny(text, _vagueSafetyTerms)) {
      return AssistantReply(
        title: ar
            ? 'أحتاج تفاصيل المنتج بالضبط'
            : 'I need the exact product details',
        message: ar
            ? 'لا أستطيع الإجابة عن أمان دواء أو جرعته من عبارة «هذا الدواء» فقط. اذكر الاسم والمادة الفعالة والتركيز والشكل وتعليمات العلبة وما أخذته وما يقلقك. لا تبدأ أو توقف أو تضاعف أو تغيّر دواءً موصوفاً بناءً على هذه الإجابة.'
            : 'I cannot answer a medicine safety or dosing question from "this medicine" alone. Provide the name, active ingredients, strength, dosage form, label directions, what was already taken, and the specific concern. Do not start, stop, double, or change a prescribed medicine based only on this prototype.',
        level: SafetyLevel.caution,
        actionLabel: 'Review medication list',
        suggestedPrompt: ar
            ? 'ما الاسم والتركيز المكتوبان على العلبة؟'
            : 'What exact name and strength are printed on the package?',
        coverage: SafetyCoverage.insufficientInformation,
        contextNote: _overallContextNote(store.safetyContext, ar),
      );
    }

    return AssistantReply(
      title: ar
          ? 'أقدر أساعدك في الخطوة التالية'
          : 'I can help organize the next step',
      message: ar
          ? 'اسألني عن جدولك أو جرعة فائتة أو مأخوذة أو التداخلات أو توقيت الأكل والمشروبات أو المكملات أو الحساسية أو الأعراض الجانبية. هذا الوضع يقدّم توجيهاً عاماً ولا يغني عن الصيدلي أو الطبيب.'
          : 'Ask about your schedule, a missed or taken dose, possible interactions, food or drink timing, supplements, allergies, or side effects. This prototype provides general routing and does not replace a pharmacist or prescriber.',
      level: SafetyLevel.general,
      suggestedPrompt: ar
          ? 'جرّب: أقدر آخذ أدويتي مع بعض؟'
          : 'Try: Can I take these medicines together?',
      coverage: SafetyCoverage.generalGuidance,
      contextNote: _overallContextNote(store.safetyContext, ar),
    );
  }

  /// Reply in the language of the message; fall back to the app language for
  /// messages with no letters at all.
  bool _replyInArabic(String prompt, AppStore store) {
    for (final rune in prompt.runes) {
      if (rune >= 0x0600 && rune <= 0x06FF) return true;
      if ((rune >= 0x41 && rune <= 0x5A) || (rune >= 0x61 && rune <= 0x7A)) {
        return false;
      }
    }
    return store.isArabic;
  }

  String _reproductiveContextNote(SafetyContext context, bool ar) {
    return switch (context.reproductiveStatus) {
      ReproductiveStatus.notAnswered =>
        ar
            ? 'حالة الحمل أو الرضاعة غير محددة في الملف الصحي.'
            : 'Pregnancy or breastfeeding status has not been reviewed in the safety profile.',
      ReproductiveStatus.preferNotToAnswer =>
        ar
            ? 'حالة الحمل أو الرضاعة غير متوفرة في الملف الصحي.'
            : 'Pregnancy or breastfeeding status is not available in the safety profile.',
      final status =>
        ar
            ? 'الحالة المحفوظة: ${_arReproductive(status)}. هذه معلومة سياقية فقط، ولم يتم فحص المنتج.'
            : 'Saved status: ${status.label}. This is context only; no product-specific check was performed.',
    };
  }

  String _organContextNote(
    SafetyContext context, {
    required bool includeKidney,
    required bool includeLiver,
    required bool ar,
  }) {
    final List<String> notes = [];
    if (includeKidney) {
      notes.add(
        ar
            ? 'الكلى: ${_arAnswer(context.kidneyStatus)}'
            : 'Kidney health: ${context.kidneyStatus.label.toLowerCase()}',
      );
    }
    if (includeLiver) {
      notes.add(
        ar
            ? 'الكبد: ${_arAnswer(context.liverStatus)}'
            : 'Liver health: ${context.liverStatus.label.toLowerCase()}',
      );
    }
    return ar
        ? '${notes.join('؛ ')}. الإجابات المحفوظة سياق فقط؛ لم يتم فحص أي تعديل للجرعة.'
        : '${notes.join('; ')}. Saved answers are context only; no dose adjustment was checked.';
  }

  String _allergyContextNote(CareProfile profile, bool ar) {
    final List<String> recorded = profile.allergies.where((allergy) {
      final String value = _normalize(allergy);
      return value.isNotEmpty &&
          value != 'none' &&
          !value.contains('no allergies') &&
          !value.contains('none known');
    }).toList();
    if (recorded.isEmpty) {
      return ar
          ? 'لا توجد حساسية مسجلة. هذا نقص في المعلومات وليس دليلاً على الأمان.'
          : 'No specific allergy is recorded. That is missing context, not proof that a product is safe.';
    }
    return ar
        ? 'الحساسية المسجلة: ${recorded.join('، ')}. لم تتم مقارنة مكونات المنتج.'
        : 'Saved allergy entries: ${recorded.join(', ')}. The ingredients in the product were not cross-checked.';
  }

  String _conditionContextNote(CareProfile profile, bool ar) {
    final List<String> recorded = profile.conditions.where((condition) {
      final String value = _normalize(condition);
      return value.isNotEmpty &&
          value != 'none' &&
          !value.contains('no conditions') &&
          !value.contains('none known');
    }).toList();
    if (recorded.isEmpty) {
      return ar
          ? 'لا توجد حالة صحية مسجلة. هذا نقص في المعلومات وليس دليلاً على مناسبة الدواء.'
          : 'No specific condition is recorded. That is missing context, not proof that a product is appropriate.';
    }
    return ar
        ? 'الحالات المسجلة: ${recorded.join('، ')}. لم يتم فحص قاعدة دواء–حالة.'
        : 'Saved condition entries: ${recorded.join(', ')}. No medicine-condition rule was checked.';
  }

  String _foodContextNote(SafetyContext context, bool ar) {
    if (!context.foodAndDrinkReviewed) {
      return ar
          ? 'عادات الأكل والمشروبات غير محددة في الملف الصحي.'
          : 'Food and drink factors have not been reviewed in the safety profile.';
    }
    if (context.foodAndDrinkFactors.isEmpty) {
      return ar
          ? 'لا توجد عادات أكل أو شرب محفوظة، وهذا لا ينفي وجود تداخل.'
          : 'No regular food or drink factor is saved. That does not rule out a medicine interaction.';
    }
    return ar
        ? 'المحفوظ: ${context.foodAndDrinkFactors.map(ArabicLabels.of).join('، ')}. هذه معلومات سياقية وليست فحصاً مكتملاً للتداخل.'
        : 'Saved food and drink factors: ${context.foodAndDrinkFactors.join(', ')}. These entries are context only, not a completed interaction check.';
  }

  String _supplementContextNote(SafetyContext context, bool ar) {
    if (!context.supplementsReviewed) {
      return ar
          ? 'المكملات والأدوية بدون وصفة غير محددة في الملف الصحي.'
          : 'Supplements and non-prescription products have not been reviewed in the safety profile.';
    }
    if (context.supplementsAndOtc.isEmpty) {
      return ar
          ? 'لا توجد مكملات أو أدوية بدون وصفة محفوظة، وهذا لا يثبت أمان التركيبة.'
          : 'No supplement or non-prescription product is saved. That does not verify a combination as safe.';
    }
    return ar
        ? 'المكملات المحفوظة: ${context.supplementsAndOtc.map(ArabicLabels.of).join('، ')}. لم تتم مقارنة مكوناتها.'
        : 'Saved supplements and non-prescription products: ${context.supplementsAndOtc.join(', ')}. Their ingredients were not cross-checked.';
  }

  String _coverageContextNote(SafetyContext context, bool ar) {
    final List<String> missing = context.priorityMissingAreas;
    final String review = ar
        ? 'أكملت ${context.reviewedAreaCount} من ${context.totalAreaCount} مجالات في الملف الصحي.'
        : '${context.reviewedAreaCount} of ${context.totalAreaCount} safety-profile areas are reviewed.';
    if (missing.isEmpty) {
      return ar
          ? '$review الملف المكتمل لا يغني عن فحص موثق للدواء.'
          : '$review A complete profile still does not replace a verified medicine check.';
    }
    return ar
        ? '$review ما زال ناقصاً: ${missing.map(_arMissingArea).join('، ')}.'
        : '$review Priority context still missing: ${missing.join(', ')}.';
  }

  String _overallContextNote(SafetyContext context, bool ar) {
    final List<String> missing = context.priorityMissingAreas;
    if (missing.isEmpty) {
      return ar
          ? 'الملف الصحي يقدّم سياقاً فقط؛ لم يتم فحص المنتج.'
          : 'The saved safety profile supplies context only; no product-specific check was performed.';
    }
    return ar
        ? 'معلومات مهمة ناقصة في الملف الصحي: ${missing.map(_arMissingArea).join('، ')}. لم يتم فحص المنتج.'
        : 'Priority safety context still missing: ${missing.join(', ')}. No product-specific check was performed.';
  }

  static String _arMissingArea(String area) => switch (area) {
    'age' => 'العمر',
    'pregnancy or breastfeeding' => 'الحمل أو الرضاعة',
    'kidney health' => 'صحة الكلى',
    'liver health' => 'صحة الكبد',
    'supplements and non-prescription products' =>
      'المكملات والأدوية بدون وصفة',
    _ => area,
  };

  static String _arAnswer(ProfileAnswer answer) => switch (answer) {
    ProfileAnswer.notAnswered => 'غير محدد',
    ProfileAnswer.no => 'لا توجد مشكلة معروفة',
    ProfileAnswer.yes => 'توجد حالة مسجلة',
    ProfileAnswer.unsure => 'غير متأكد',
  };

  static String _arReproductive(ReproductiveStatus status) => switch (status) {
    ReproductiveStatus.notAnswered => 'غير محدد',
    ReproductiveStatus.notApplicable => 'لا ينطبق',
    ReproductiveStatus.pregnant => 'حامل',
    ReproductiveStatus.breastfeeding => 'مرضع',
    ReproductiveStatus.tryingToConceive => 'تحاول الحمل',
    ReproductiveStatus.postpartum => 'وضعت مؤخراً',
    ReproductiveStatus.none => 'لا شيء مما سبق',
    ReproductiveStatus.preferNotToAnswer => 'تفضيل عدم الإجابة',
  };

  bool _containsAny(String text, List<String> values) {
    return values.any((value) => _containsPhrase(text, _normalize(value)));
  }

  bool _containsPhrase(String text, String phrase) {
    // Arabic attaches prefixes such as و، ال، ب to words, so Arabic phrases
    // match anywhere; Latin phrases still need whole-word boundaries.
    if (phrase.runes.any((rune) => rune >= 0x0600 && rune <= 0x06FF)) {
      return text.contains(phrase);
    }
    return text == phrase ||
        text.startsWith('$phrase ') ||
        text.endsWith(' $phrase') ||
        text.contains(' $phrase ');
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('’', "'")
        .replaceAll(RegExp(r'[ً-ٰٟـ]'), '')
        .replaceAll(RegExp(r'[أإآ]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll(RegExp(r'[،؛؟]'), ' ')
        .replaceAll(RegExp(r"[^a-z0-9'؀-ۿ]+"), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
