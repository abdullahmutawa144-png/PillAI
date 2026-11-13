import 'app_models.dart';
import 'assistant_provenance.dart';

/// JSON encoding for everything the store persists.
///
/// Decoders are deliberately forgiving: a malformed entry is skipped instead
/// of failing the whole restore, so one bad record never locks a user out of
/// their medication plan.
abstract final class StoreSnapshotCodec {
  static const int version = 2;

  static Map<String, Object?> profile(CareProfile value) => {
    'name': value.name,
    'conditions': value.conditions,
    'allergies': value.allergies,
    'wakeTimeLabel': value.wakeTimeLabel,
    'sleepTimeLabel': value.sleepTimeLabel,
    'weightLabel': value.weightLabel,
    'preferredLanguage': value.preferredLanguage,
  };

  static CareProfile? decodeProfile(Object? raw, CareProfile fallback) {
    if (raw is! Map) return null;
    final value = raw.cast<String, Object?>();
    return CareProfile(
      name: _string(value['name']) ?? fallback.name,
      conditions: _stringList(value['conditions']) ?? fallback.conditions,
      allergies: _stringList(value['allergies']) ?? fallback.allergies,
      wakeTimeLabel: _string(value['wakeTimeLabel']) ?? fallback.wakeTimeLabel,
      sleepTimeLabel:
          _string(value['sleepTimeLabel']) ?? fallback.sleepTimeLabel,
      weightLabel: _string(value['weightLabel']) ?? fallback.weightLabel,
      preferredLanguage:
          _string(value['preferredLanguage']) ?? fallback.preferredLanguage,
    );
  }

  static Map<String, Object?> safetyContext(SafetyContext value) => {
    'ageRange': value.ageRange,
    'sexForMedicationSafety': value.sexForMedicationSafety,
    'reproductiveStatus': value.reproductiveStatus.name,
    'kidneyStatus': value.kidneyStatus.name,
    'liverStatus': value.liverStatus.name,
    'foodAndDrinkFactors': value.foodAndDrinkFactors,
    'supplementsAndOtc': value.supplementsAndOtc,
    'lifestyleFactors': value.lifestyleFactors,
    'accessibilityNeeds': value.accessibilityNeeds,
    'foodAndDrinkReviewed': value.foodAndDrinkReviewed,
    'supplementsReviewed': value.supplementsReviewed,
    'lifestyleReviewed': value.lifestyleReviewed,
    'accessibilityReviewed': value.accessibilityReviewed,
    'lastReviewedAt': value.lastReviewedAt?.toIso8601String(),
  };

  static SafetyContext? decodeSafetyContext(Object? raw) {
    if (raw is! Map) return null;
    final value = raw.cast<String, Object?>();
    const fallback = SafetyContext();
    return SafetyContext(
      ageRange: _string(value['ageRange']) ?? fallback.ageRange,
      sexForMedicationSafety:
          _string(value['sexForMedicationSafety']) ??
          fallback.sexForMedicationSafety,
      reproductiveStatus: _enum(
        ReproductiveStatus.values,
        value['reproductiveStatus'],
        fallback.reproductiveStatus,
      ),
      kidneyStatus: _enum(
        ProfileAnswer.values,
        value['kidneyStatus'],
        fallback.kidneyStatus,
      ),
      liverStatus: _enum(
        ProfileAnswer.values,
        value['liverStatus'],
        fallback.liverStatus,
      ),
      foodAndDrinkFactors: _stringList(value['foodAndDrinkFactors']) ?? [],
      supplementsAndOtc: _stringList(value['supplementsAndOtc']) ?? [],
      lifestyleFactors: _stringList(value['lifestyleFactors']) ?? [],
      accessibilityNeeds: _stringList(value['accessibilityNeeds']) ?? [],
      foodAndDrinkReviewed: value['foodAndDrinkReviewed'] == true,
      supplementsReviewed: value['supplementsReviewed'] == true,
      lifestyleReviewed: value['lifestyleReviewed'] == true,
      accessibilityReviewed: value['accessibilityReviewed'] == true,
      lastReviewedAt: _date(value['lastReviewedAt']),
    );
  }

  static Map<String, Object?> memoryFact(MedicationMemoryFact fact) => {
    'id': fact.id,
    'kind': fact.kind.name,
    'value': fact.value,
    'status': fact.status.name,
    'recordedAt': fact.recordedAt.toIso8601String(),
    'occurredAt': fact.occurredAt?.toIso8601String(),
    'medicationIds': fact.medicationIds,
  };

  static MedicationMemoryFact? decodeMemoryFact(Object? raw) {
    if (raw is! Map) return null;
    final value = raw.cast<String, Object?>();
    final id = _string(value['id']);
    final text = _string(value['value']);
    final recordedAt = _date(value['recordedAt']);
    if (id == null || text == null || recordedAt == null) return null;
    return MedicationMemoryFact(
      id: id,
      kind: _enum(
        MedicationMemoryKind.values,
        value['kind'],
        MedicationMemoryKind.other,
      ),
      value: text,
      status: _enum(
        MemoryFactStatus.values,
        value['status'],
        MemoryFactStatus.reported,
      ),
      recordedAt: recordedAt,
      occurredAt: _date(value['occurredAt']),
      medicationIds: _stringList(value['medicationIds']) ?? const [],
    );
  }

  static Map<String, Object?> medication(Medication value) => {
    'id': value.id,
    'name': value.name,
    'strength': value.strength,
    'form': value.form.name,
    'doseLabel': value.doseLabel,
    'instructions': value.instructions,
    'colorSeed': value.colorSeed,
    'isPrescription': value.isPrescription,
    'activeIngredients': value.activeIngredients,
    if (value.schedule != null)
      'schedule': {
        'times': value.schedule!.times,
        'startDate': _dateOnly(value.schedule!.startDate),
        'durationDays': value.schedule!.durationDays,
      },
  };

  static Medication? decodeMedication(Object? raw) {
    if (raw is! Map) return null;
    final value = raw.cast<String, Object?>();
    final id = _string(value['id']);
    final name = _string(value['name']);
    if (id == null || name == null) return null;
    MedicationSchedule? schedule;
    final rawSchedule = value['schedule'];
    if (rawSchedule is Map) {
      final s = rawSchedule.cast<String, Object?>();
      final start = _date(s['startDate']);
      final times = s['times'];
      if (start != null && times is List) {
        schedule = MedicationSchedule(
          times: times.whereType<int>().toList(),
          startDate: start,
          durationDays: s['durationDays'] is int
              ? s['durationDays'] as int
              : null,
        );
      }
    }
    return Medication(
      id: id,
      name: name,
      strength: _string(value['strength']) ?? '',
      form: _enum(MedicationForm.values, value['form'], MedicationForm.other),
      doseLabel: _string(value['doseLabel']) ?? '',
      instructions: _string(value['instructions']) ?? '',
      colorSeed: value['colorSeed'] is int ? value['colorSeed'] as int : 0,
      isPrescription: value['isPrescription'] == true,
      activeIngredients: _stringList(value['activeIngredients']) ?? const [],
      schedule: schedule,
    );
  }

  static Map<String, Object?> dose(DoseOccurrence value) => {
    'id': value.id,
    'medicationId': value.medicationId,
    'scheduledAt': value.scheduledAt.toIso8601String(),
    'status': value.status.name,
    'actualAt': value.actualAt?.toIso8601String(),
    'missedReason': value.missedReason,
    'originalScheduledAt': value.originalScheduledAt?.toIso8601String(),
  };

  static DoseOccurrence? decodeDose(Object? raw) {
    if (raw is! Map) return null;
    final value = raw.cast<String, Object?>();
    final id = _string(value['id']);
    final medicationId = _string(value['medicationId']);
    final scheduledAt = _date(value['scheduledAt']);
    if (id == null || medicationId == null || scheduledAt == null) return null;
    return DoseOccurrence(
      id: id,
      medicationId: medicationId,
      scheduledAt: scheduledAt,
      status: _enum(DoseStatus.values, value['status'], DoseStatus.scheduled),
      actualAt: _date(value['actualAt']),
      missedReason: _string(value['missedReason']),
      originalScheduledAt: _date(value['originalScheduledAt']),
    );
  }

  static Map<String, Object?> event(DoseEvent value) => {
    'doseId': value.doseId,
    'type': value.type.name,
    'recordedAt': value.recordedAt.toIso8601String(),
    'note': value.note,
  };

  static DoseEvent? decodeEvent(Object? raw) {
    if (raw is! Map) return null;
    final value = raw.cast<String, Object?>();
    final doseId = _string(value['doseId']);
    final recordedAt = _date(value['recordedAt']);
    if (doseId == null || recordedAt == null) return null;
    return DoseEvent(
      doseId: doseId,
      type: _enum(DoseStatus.values, value['type'], DoseStatus.scheduled),
      recordedAt: recordedAt,
      note: _string(value['note']),
    );
  }

  static Map<String, Object?> message(ChatMessage value) {
    final reply = value.reply;
    final provenance = value.provenance;
    return {
      'text': value.text,
      'isUser': value.isUser,
      'sentAt': value.sentAt.toIso8601String(),
      if (reply != null)
        'reply': {
          'title': reply.title,
          'message': reply.message,
          'level': reply.level.name,
          'coverage': reply.coverage.name,
          'actionLabel': reply.actionLabel,
          'suggestedPrompt': reply.suggestedPrompt,
          'contextNote': reply.contextNote,
          'sources': [
            for (final source in reply.sources)
              {
                'title': source.title,
                'url': source.url,
                'support': source.support,
              },
          ],
        },
      if (provenance != null)
        'provenance': {
          'source': provenance.source.name,
          'model': provenance.model,
          'fallbackReason': provenance.fallbackReason?.name,
          'safetyGate': provenance.safetyGate?.name,
        },
    };
  }

  static ChatMessage? decodeMessage(Object? raw) {
    if (raw is! Map) return null;
    final value = raw.cast<String, Object?>();
    final text = _string(value['text']);
    final sentAt = _date(value['sentAt']);
    if (text == null || sentAt == null) return null;
    AssistantReply? reply;
    final rawReply = value['reply'];
    if (rawReply is Map) {
      final r = rawReply.cast<String, Object?>();
      final sources = r['sources'];
      reply = AssistantReply(
        title: _string(r['title']) ?? '',
        message: _string(r['message']) ?? text,
        level: _enum(SafetyLevel.values, r['level'], SafetyLevel.general),
        coverage: _enum(
          SafetyCoverage.values,
          r['coverage'],
          SafetyCoverage.generalGuidance,
        ),
        actionLabel: _string(r['actionLabel']),
        suggestedPrompt: _string(r['suggestedPrompt']),
        contextNote: _string(r['contextNote']),
        sources: [
          if (sources is List)
            for (final source in sources.whereType<Map>())
              if (_string(source['url']) != null)
                EvidenceSource(
                  title: _string(source['title']) ?? '',
                  url: _string(source['url'])!,
                  support: _string(source['support']) ?? '',
                ),
        ],
      );
    }
    AssistantAnswerProvenance? provenance;
    final rawProvenance = value['provenance'];
    if (rawProvenance is Map) {
      final p = rawProvenance.cast<String, Object?>();
      provenance = AssistantAnswerProvenance(
        source: _enum(
          AssistantResponseSource.values,
          p['source'],
          AssistantResponseSource.demoFallback,
        ),
        model: _string(p['model']),
        fallbackReason: _nullableEnum(
          AssistantFallbackReason.values,
          p['fallbackReason'],
        ),
        safetyGate: _nullableEnum(AssistantSafetyGate.values, p['safetyGate']),
      );
    }
    return ChatMessage(
      text: text,
      isUser: value['isUser'] == true,
      sentAt: sentAt,
      reply: reply,
      provenance: provenance,
    );
  }

  static List<T> decodeList<T>(Object? raw, T? Function(Object?) decode) {
    if (raw is! List) return <T>[];
    return [
      for (final item in raw)
        if (decode(item) case final T value) value,
    ];
  }

  static String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static String? _string(Object? value) => value is String ? value : null;

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  static List<String>? _stringList(Object? value) {
    if (value is! List || value.any((item) => item is! String)) return null;
    return value.cast<String>().toList();
  }

  static T _enum<T extends Enum>(List<T> values, Object? name, T fallback) {
    return _nullableEnum(values, name) ?? fallback;
  }

  static T? _nullableEnum<T extends Enum>(List<T> values, Object? name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }
}
