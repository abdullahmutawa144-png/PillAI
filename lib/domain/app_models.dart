import 'assistant_provenance.dart';

enum MedicationForm { tablet, capsule, liquid, injection, other }

enum DoseStatus { scheduled, due, taken, missed, snoozed, adjusted }

enum SafetyLevel { general, caution, urgent }

enum AppDisplayMode { standard, simple }

/// The two launch languages. The value names double as the
/// `preferredLanguage` strings the backend already accepts.
enum AppLanguage {
  english('English', 'en'),
  arabic('Arabic', 'ar');

  const AppLanguage(this.profileValue, this.code);

  final String profileValue;
  final String code;

  static AppLanguage fromProfileValue(String? value) {
    return value == AppLanguage.arabic.profileValue
        ? AppLanguage.arabic
        : AppLanguage.english;
  }
}

enum ProfileAnswer { notAnswered, no, yes, unsure }

enum ReproductiveStatus {
  notAnswered,
  notApplicable,
  pregnant,
  breastfeeding,
  tryingToConceive,
  postpartum,
  none,
  preferNotToAnswer,
}

enum SafetyCoverage {
  generalGuidance,
  insufficientInformation,
  verifiedIssue,
  notChecked,
}

enum MedicationMemoryKind {
  foodDrink,
  supplementOtc,
  healthStatus,
  condition,
  allergy,
  symptom,
  routine,
  medicationExperience,
  preference,
  other,
}

enum MemoryFactStatus { reported, confirmed, uncertain }

enum AssistantDoseAction { none, taken, missed, snoozed }

enum AssistantConfidence { high, medium, low }

extension ProfileAnswerLabel on ProfileAnswer {
  String get label => switch (this) {
    ProfileAnswer.notAnswered => 'Not reviewed',
    ProfileAnswer.no => 'No known issue',
    ProfileAnswer.yes => 'Condition recorded',
    ProfileAnswer.unsure => 'Not sure',
  };
}

extension ReproductiveStatusLabel on ReproductiveStatus {
  String get label => switch (this) {
    ReproductiveStatus.notAnswered => 'Not reviewed',
    ReproductiveStatus.notApplicable => 'Not applicable',
    ReproductiveStatus.pregnant => 'Pregnant',
    ReproductiveStatus.breastfeeding => 'Breastfeeding',
    ReproductiveStatus.tryingToConceive => 'Trying to conceive',
    ReproductiveStatus.postpartum => 'Recently postpartum',
    ReproductiveStatus.none => 'None of these',
    ReproductiveStatus.preferNotToAnswer => 'Prefer not to answer',
  };
}

class SafetyContext {
  const SafetyContext({
    this.ageRange = 'Not added',
    this.sexForMedicationSafety = 'Not added',
    this.reproductiveStatus = ReproductiveStatus.notAnswered,
    this.kidneyStatus = ProfileAnswer.notAnswered,
    this.liverStatus = ProfileAnswer.notAnswered,
    this.foodAndDrinkFactors = const [],
    this.supplementsAndOtc = const [],
    this.lifestyleFactors = const [],
    this.accessibilityNeeds = const [],
    this.foodAndDrinkReviewed = false,
    this.supplementsReviewed = false,
    this.lifestyleReviewed = false,
    this.accessibilityReviewed = false,
    this.lastReviewedAt,
  });

  final String ageRange;
  final String sexForMedicationSafety;
  final ReproductiveStatus reproductiveStatus;
  final ProfileAnswer kidneyStatus;
  final ProfileAnswer liverStatus;
  final List<String> foodAndDrinkFactors;
  final List<String> supplementsAndOtc;
  final List<String> lifestyleFactors;
  final List<String> accessibilityNeeds;
  final bool foodAndDrinkReviewed;
  final bool supplementsReviewed;
  final bool lifestyleReviewed;
  final bool accessibilityReviewed;
  final DateTime? lastReviewedAt;

  int get reviewedAreaCount {
    var count = 0;
    if (ageRange != 'Not added') count++;
    if (reproductiveStatus != ReproductiveStatus.notAnswered) count++;
    if (kidneyStatus != ProfileAnswer.notAnswered) count++;
    if (liverStatus != ProfileAnswer.notAnswered) count++;
    if (foodAndDrinkReviewed) count++;
    if (supplementsReviewed) count++;
    if (lifestyleReviewed) count++;
    if (accessibilityReviewed) count++;
    return count;
  }

  int get totalAreaCount => 8;

  double get completion => reviewedAreaCount / totalAreaCount;

  List<String> get priorityMissingAreas {
    return [
      if (ageRange == 'Not added') 'age',
      if (reproductiveStatus == ReproductiveStatus.notAnswered)
        'pregnancy or breastfeeding',
      if (kidneyStatus == ProfileAnswer.notAnswered) 'kidney health',
      if (liverStatus == ProfileAnswer.notAnswered) 'liver health',
      if (!supplementsReviewed) 'supplements and non-prescription products',
    ];
  }

  SafetyContext copyWith({
    String? ageRange,
    String? sexForMedicationSafety,
    ReproductiveStatus? reproductiveStatus,
    ProfileAnswer? kidneyStatus,
    ProfileAnswer? liverStatus,
    List<String>? foodAndDrinkFactors,
    List<String>? supplementsAndOtc,
    List<String>? lifestyleFactors,
    List<String>? accessibilityNeeds,
    bool? foodAndDrinkReviewed,
    bool? supplementsReviewed,
    bool? lifestyleReviewed,
    bool? accessibilityReviewed,
    DateTime? lastReviewedAt,
  }) {
    return SafetyContext(
      ageRange: ageRange ?? this.ageRange,
      sexForMedicationSafety:
          sexForMedicationSafety ?? this.sexForMedicationSafety,
      reproductiveStatus: reproductiveStatus ?? this.reproductiveStatus,
      kidneyStatus: kidneyStatus ?? this.kidneyStatus,
      liverStatus: liverStatus ?? this.liverStatus,
      foodAndDrinkFactors: foodAndDrinkFactors ?? this.foodAndDrinkFactors,
      supplementsAndOtc: supplementsAndOtc ?? this.supplementsAndOtc,
      lifestyleFactors: lifestyleFactors ?? this.lifestyleFactors,
      accessibilityNeeds: accessibilityNeeds ?? this.accessibilityNeeds,
      foodAndDrinkReviewed: foodAndDrinkReviewed ?? this.foodAndDrinkReviewed,
      supplementsReviewed: supplementsReviewed ?? this.supplementsReviewed,
      lifestyleReviewed: lifestyleReviewed ?? this.lifestyleReviewed,
      accessibilityReviewed:
          accessibilityReviewed ?? this.accessibilityReviewed,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
    );
  }
}

class CareProfile {
  const CareProfile({
    required this.name,
    required this.conditions,
    required this.allergies,
    required this.wakeTimeLabel,
    required this.sleepTimeLabel,
    this.weightLabel = 'Not added',
    this.preferredLanguage = 'English',
  });

  final String name;
  final List<String> conditions;
  final List<String> allergies;
  final String wakeTimeLabel;
  final String sleepTimeLabel;
  final String weightLabel;
  final String preferredLanguage;

  CareProfile copyWith({
    String? name,
    List<String>? conditions,
    List<String>? allergies,
    String? wakeTimeLabel,
    String? sleepTimeLabel,
    String? weightLabel,
    String? preferredLanguage,
  }) {
    return CareProfile(
      name: name ?? this.name,
      conditions: conditions ?? this.conditions,
      allergies: allergies ?? this.allergies,
      wakeTimeLabel: wakeTimeLabel ?? this.wakeTimeLabel,
      sleepTimeLabel: sleepTimeLabel ?? this.sleepTimeLabel,
      weightLabel: weightLabel ?? this.weightLabel,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
    );
  }
}

/// When a medicine's reminders happen.
///
/// Times are minutes after local midnight. An empty list means "as needed":
/// the medicine is kept on record but never generates reminders.
class MedicationSchedule {
  MedicationSchedule({
    required List<int> times,
    required DateTime startDate,
    this.durationDays,
  }) : times = List.unmodifiable(
         times
             .where((minute) => minute >= 0 && minute < 24 * 60)
             .toSet()
             .toList()
           ..sort(),
       ),
       startDate = DateTime(startDate.year, startDate.month, startDate.day);

  final List<int> times;
  final DateTime startDate;

  /// Course length in days, or null for an ongoing medicine.
  final int? durationDays;

  bool get isAsNeeded => times.isEmpty;
  bool get isOngoing => durationDays == null;

  /// The last calendar day that has reminders, or null when ongoing.
  DateTime? get endDate => durationDays == null
      ? null
      : DateTime(
          startDate.year,
          startDate.month,
          startDate.day + durationDays! - 1,
        );

  bool isActiveOn(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    if (date.isBefore(startDate)) return false;
    final end = endDate;
    return end == null || !date.isAfter(end);
  }

  /// Days left including [today], or null when ongoing.
  int? daysLeft(DateTime today) {
    final end = endDate;
    if (end == null) return null;
    final date = DateTime(today.year, today.month, today.day);
    if (date.isAfter(end)) return 0;
    final from = date.isBefore(startDate) ? startDate : date;
    return DateTime.utc(
          end.year,
          end.month,
          end.day,
        ).difference(DateTime.utc(from.year, from.month, from.day)).inDays +
        1;
  }

  MedicationSchedule copyWith({
    List<int>? times,
    DateTime? startDate,
    int? Function()? durationDays,
  }) {
    return MedicationSchedule(
      times: times ?? this.times,
      startDate: startDate ?? this.startDate,
      durationDays: durationDays == null ? this.durationDays : durationDays(),
    );
  }
}

class Medication {
  const Medication({
    required this.id,
    required this.name,
    required this.strength,
    required this.form,
    required this.doseLabel,
    required this.instructions,
    required this.colorSeed,
    this.isPrescription = false,
    this.activeIngredients = const [],
    this.schedule,
  });

  final String id;
  final String name;
  final String strength;
  final MedicationForm form;
  final String doseLabel;
  final String instructions;
  final int colorSeed;
  final bool isPrescription;
  final List<String> activeIngredients;

  /// Null only for records created before schedules existed.
  final MedicationSchedule? schedule;

  String get displayName => strength.trim().isEmpty ? name : '$name $strength';

  Medication copyWith({
    String? name,
    String? strength,
    MedicationForm? form,
    String? doseLabel,
    String? instructions,
    bool? isPrescription,
    List<String>? activeIngredients,
    MedicationSchedule? schedule,
  }) {
    return Medication(
      id: id,
      name: name ?? this.name,
      strength: strength ?? this.strength,
      form: form ?? this.form,
      doseLabel: doseLabel ?? this.doseLabel,
      instructions: instructions ?? this.instructions,
      colorSeed: colorSeed,
      isPrescription: isPrescription ?? this.isPrescription,
      activeIngredients: activeIngredients ?? this.activeIngredients,
      schedule: schedule ?? this.schedule,
    );
  }
}

class DoseOccurrence {
  const DoseOccurrence({
    required this.id,
    required this.medicationId,
    required this.scheduledAt,
    required this.status,
    this.actualAt,
    this.missedReason,
    this.originalScheduledAt,
  });

  final String id;
  final String medicationId;
  final DateTime scheduledAt;
  final DoseStatus status;
  final DateTime? actualAt;
  final String? missedReason;
  final DateTime? originalScheduledAt;

  DoseOccurrence copyWith({
    DateTime? scheduledAt,
    DoseStatus? status,
    DateTime? actualAt,
    String? missedReason,
    DateTime? originalScheduledAt,
  }) {
    return DoseOccurrence(
      id: id,
      medicationId: medicationId,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      status: status ?? this.status,
      actualAt: actualAt ?? this.actualAt,
      missedReason: missedReason ?? this.missedReason,
      originalScheduledAt: originalScheduledAt ?? this.originalScheduledAt,
    );
  }
}

class DoseEvent {
  const DoseEvent({
    required this.doseId,
    required this.type,
    required this.recordedAt,
    this.note,
  });

  final String doseId;
  final DoseStatus type;
  final DateTime recordedAt;
  final String? note;
}

class MedicationMemoryFact {
  const MedicationMemoryFact({
    required this.id,
    required this.kind,
    required this.value,
    required this.status,
    required this.recordedAt,
    this.occurredAt,
    this.medicationIds = const [],
  });

  final String id;
  final MedicationMemoryKind kind;
  final String value;
  final MemoryFactStatus status;
  final DateTime recordedAt;
  final DateTime? occurredAt;
  final List<String> medicationIds;
}

class EvidenceSource {
  const EvidenceSource({
    required this.title,
    required this.url,
    required this.support,
  });

  final String title;
  final String url;
  final String support;
}

class AssistantDoseEvent {
  const AssistantDoseEvent({
    required this.action,
    required this.confidence,
    this.doseId,
    this.occurredAt,
    this.note,
  });

  final AssistantDoseAction action;
  final AssistantConfidence confidence;
  final String? doseId;
  final DateTime? occurredAt;
  final String? note;
}

class ScheduleChange {
  const ScheduleChange({
    required this.doseId,
    required this.medicationName,
    required this.from,
    required this.to,
    required this.reason,
    required this.sourceUrl,
  });

  final String doseId;
  final String medicationName;
  final DateTime from;
  final DateTime to;
  final String reason;
  final String sourceUrl;
}

class RescheduleProposal {
  const RescheduleProposal({
    required this.doseId,
    required this.medicationName,
    required this.from,
    required this.to,
    required this.reason,
    required this.canApply,
    required this.safetyNote,
    this.changes = const [],
  });

  final String doseId;
  final String medicationName;
  final DateTime from;
  final DateTime to;
  final String reason;
  final bool canApply;
  final String safetyNote;
  final List<ScheduleChange> changes;

  List<ScheduleChange> get allChanges => changes.isNotEmpty
      ? changes
      : [
          ScheduleChange(
            doseId: doseId,
            medicationName: medicationName,
            from: from,
            to: to,
            reason: reason,
            sourceUrl: '',
          ),
        ];
}

class AssistantReply {
  const AssistantReply({
    required this.title,
    required this.message,
    required this.level,
    this.actionLabel,
    this.suggestedPrompt,
    this.coverage = SafetyCoverage.generalGuidance,
    this.contextNote,
    this.sources = const [],
  });

  final String title;
  final String message;
  final SafetyLevel level;
  final String? actionLabel;
  final String? suggestedPrompt;
  final SafetyCoverage coverage;
  final String? contextNote;
  final List<EvidenceSource> sources;
}

class ChatMessage {
  const ChatMessage({
    required this.text,
    required this.isUser,
    required this.sentAt,
    this.reply,
    this.provenance,
  });

  final String text;
  final bool isUser;
  final DateTime sentAt;
  final AssistantReply? reply;
  final AssistantAnswerProvenance? provenance;
}
