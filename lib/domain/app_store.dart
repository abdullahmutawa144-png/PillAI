import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/demo_data.dart';
import 'app_models.dart';
import 'state_storage.dart';
import 'store_snapshot.dart';

/// Where a dose stands relative to "now", for display only.
enum DoseTiming { upcoming, dueNow, overdue, taken, missed }

class AppStore extends ChangeNotifier {
  AppStore._(this._clock, this._storage, {required this.usesLiveClock});

  /// A ready-to-use store holding the sample plan.
  ///
  /// Tests pass a fixed [clock] so "today" never drifts. Nothing is persisted
  /// unless a [storage] is supplied.
  factory AppStore.demo({DateTime? clock, StateStorage? storage}) {
    final store = AppStore._(
      clock == null ? DateTime.now : () => clock,
      storage,
      usesLiveClock: clock == null,
    );
    store
      ..profile = DemoData.profile
      ..safetyContext = DemoData.safetyContext
      .._onboardingComplete = true
      .._isLoaded = true;
    store._addSampleMedications();
    store._materializeWindow();
    store._ready.complete();
    return store;
  }

  /// The production store: starts empty, restores the saved snapshot, and
  /// asks for onboarding when nothing has been saved yet.
  factory AppStore.persistent({
    required StateStorage storage,
    DateTime Function()? clock,
    AppLanguage initialLanguage = AppLanguage.english,
  }) {
    final store = AppStore._(
      clock ?? DateTime.now,
      storage,
      usesLiveClock: clock == null,
    );
    store
      ..profile = CareProfile(
        name: '',
        conditions: const ['No conditions recorded'],
        allergies: const ['No allergies recorded'],
        wakeTimeLabel: '7:00 AM',
        sleepTimeLabel: '11:00 PM',
        preferredLanguage: initialLanguage.profileValue,
      )
      ..safetyContext = const SafetyContext();
    unawaited(store._load());
    return store;
  }

  final DateTime Function() _clock;
  final StateStorage? _storage;

  /// False when a test froze the clock; the app shell only runs its minute
  /// ticker against the real clock.
  final bool usesLiveClock;

  late CareProfile profile;
  late SafetyContext safetyContext;
  AppDisplayMode _displayMode = AppDisplayMode.standard;
  bool _isLoaded = false;
  bool _onboardingComplete = false;
  bool? _remoteAiConsent;
  bool _voiceNoticeAccepted = false;
  int _colorCursor = 0;
  DateTime? _windowDay;
  int _lastTickMinute = -1;
  Future<void> _pendingWrite = Future<void>.value();
  final Completer<void> _ready = Completer<void>();

  final List<Medication> _medications = [];
  final List<DoseOccurrence> _doses = [];
  final Set<String> _doseIds = {};
  final List<DoseEvent> _events = [];
  final List<ChatMessage> _messages = [];
  final List<MedicationMemoryFact> _memoryFacts = [];
  RescheduleProposal? _pendingProposal;

  static const int _windowPastDays = 14;
  static const int _windowFutureDays = 14;
  static const int _keepHistoryDays = 60;
  static const int _maxEvents = 500;
  static const int _maxSavedMessages = 40;

  DateTime get now => _clock();
  DateTime get today => _dateOnly(now);

  bool get isLoaded => _isLoaded;

  /// Completes once the saved snapshot (if any) has been restored.
  Future<void> get ready => _ready.future;

  /// Completes after every write queued so far has reached storage.
  Future<void> get saved => _pendingWrite;
  bool get onboardingComplete => _onboardingComplete;

  /// Null until the user has made a choice about sending context to live AI.
  bool? get remoteAiConsent => _remoteAiConsent;
  bool get voiceNoticeAccepted => _voiceNoticeAccepted;

  AppDisplayMode get displayMode => _displayMode;
  bool get isSimpleMode => _displayMode == AppDisplayMode.simple;

  AppLanguage get language =>
      AppLanguage.fromProfileValue(profile.preferredLanguage);
  bool get isArabic => language == AppLanguage.arabic;

  List<Medication> get medications => List.unmodifiable(_medications);
  List<DoseOccurrence> get doses {
    _materializeWindow();
    final result = List<DoseOccurrence>.of(_doses)
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return List.unmodifiable(result);
  }

  List<DoseOccurrence> get todayDoses => dosesOn(now);

  List<DoseOccurrence> dosesOn(DateTime day) {
    return doses.where((dose) => _isSameDay(dose.scheduledAt, day)).toList();
  }

  List<DoseEvent> get events => List.unmodifiable(_events);
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  List<MedicationMemoryFact> get memoryFacts => List.unmodifiable(_memoryFacts);
  RescheduleProposal? get pendingProposal => _pendingProposal;

  DoseOccurrence? get nextDose {
    final active = todayDoses.where(_isOpen);
    return active.isEmpty ? null : active.first;
  }

  int get completedToday =>
      todayDoses.where((dose) => dose.status == DoseStatus.taken).length;
  int get totalToday => todayDoses.length;
  double get adherenceToday =>
      totalToday == 0 ? 0 : completedToday / totalToday;

  DoseTiming timingOf(DoseOccurrence dose) {
    if (dose.status == DoseStatus.taken) return DoseTiming.taken;
    if (dose.status == DoseStatus.missed) return DoseTiming.missed;
    final current = now;
    if (dose.scheduledAt.isAfter(current.add(const Duration(minutes: 15)))) {
      return DoseTiming.upcoming;
    }
    return current.difference(dose.scheduledAt) <= const Duration(hours: 1)
        ? DoseTiming.dueNow
        : DoseTiming.overdue;
  }

  Medication medicationFor(String id) {
    return _medications.firstWhere((medication) => medication.id == id);
  }

  Medication? medicationOrNull(String id) {
    for (final medication in _medications) {
      if (medication.id == id) return medication;
    }
    return null;
  }

  DoseOccurrence doseFor(String id) {
    return _doses.firstWhere((dose) => dose.id == id);
  }

  // ---------------------------------------------------------------------------
  // Dose actions

  void markTaken(String doseId, {DateTime? at}) {
    final dose = doseFor(doseId);
    final when = at ?? now;
    _replaceDose(dose.copyWith(status: DoseStatus.taken, actualAt: when));
    _recordEvent(
      DoseEvent(doseId: doseId, type: DoseStatus.taken, recordedAt: when),
    );
    if (_pendingProposal?.doseId == doseId) _pendingProposal = null;
    _changed();
  }

  void snoozeDose(
    String doseId, {
    Duration duration = const Duration(minutes: 10),
  }) {
    final dose = doseFor(doseId);
    // Snoozing an overdue dose moves it relative to now, not to its old slot.
    final base = dose.scheduledAt.isBefore(now) ? now : dose.scheduledAt;
    _replaceDose(
      dose.copyWith(
        status: DoseStatus.snoozed,
        scheduledAt: base.add(duration),
        originalScheduledAt: dose.originalScheduledAt ?? dose.scheduledAt,
      ),
    );
    _recordEvent(
      DoseEvent(
        doseId: doseId,
        type: DoseStatus.snoozed,
        recordedAt: now,
        note: 'Reminder snoozed by ${duration.inMinutes} minutes',
      ),
    );
    _changed();
  }

  RescheduleProposal markMissed(String doseId, String reason) {
    final dose = doseFor(doseId);
    final medication = medicationFor(dose.medicationId);
    _replaceDose(
      dose.copyWith(status: DoseStatus.missed, missedReason: reason),
    );
    _recordEvent(
      DoseEvent(
        doseId: doseId,
        type: DoseStatus.missed,
        recordedAt: now,
        note: reason,
      ),
    );

    _pendingProposal = RescheduleProposal(
      doseId: dose.id,
      medicationName: medication.name,
      from: dose.scheduledAt,
      to: dose.scheduledAt,
      reason: reason,
      canApply: false,
      safetyNote:
          'Missed dose recorded. No reminder was moved because PillAI does not yet have a verified, product-specific missed-dose rule. Follow the medicine label or contact a pharmacist before changing the timing.',
    );
    _changed();
    return _pendingProposal!;
  }

  /// Returns a taken or missed dose to its planned state, for mistaken taps.
  void undoDose(String doseId) {
    final dose = doseFor(doseId);
    _replaceDose(
      DoseOccurrence(
        id: dose.id,
        medicationId: dose.medicationId,
        scheduledAt: dose.scheduledAt,
        status: dose.originalScheduledAt == null
            ? DoseStatus.scheduled
            : DoseStatus.adjusted,
        originalScheduledAt: dose.originalScheduledAt,
      ),
    );
    _recordEvent(
      DoseEvent(
        doseId: doseId,
        type: DoseStatus.scheduled,
        recordedAt: now,
        note: 'Undo: previously ${dose.status.name}',
      ),
    );
    if (_pendingProposal?.doseId == doseId) _pendingProposal = null;
    _changed();
  }

  void confirmReschedule() {
    final proposal = _pendingProposal;
    if (proposal == null || !proposal.canApply) return;
    for (final change in proposal.allChanges) {
      final dose = doseFor(change.doseId);
      _replaceDose(
        dose.copyWith(
          status: DoseStatus.adjusted,
          scheduledAt: change.to,
          originalScheduledAt: dose.originalScheduledAt ?? change.from,
        ),
      );
      _recordEvent(
        DoseEvent(
          doseId: change.doseId,
          type: DoseStatus.adjusted,
          recordedAt: now,
          note: 'AI proposal confirmed: ${change.reason}',
        ),
      );
    }
    _pendingProposal = null;
    _changed();
  }

  void dismissProposal() {
    _pendingProposal = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Medications

  /// Adds a medicine and its reminders.
  ///
  /// Pass [times] (minutes after midnight) for a recurring plan. The older
  /// [firstDoseAt] form creates one daily reminder at that time, starting that
  /// day. Neither means "as needed": on record, but no reminders.
  Medication addMedication({
    required String name,
    required String strength,
    required MedicationForm form,
    required String doseLabel,
    required String instructions,
    DateTime? firstDoseAt,
    List<int>? times,
    DateTime? startDate,
    int? durationDays,
    bool isPrescription = false,
    List<String> activeIngredients = const [],
  }) {
    final slug = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final id =
        '${slug.isEmpty ? 'med' : slug}-${DateTime.now().microsecondsSinceEpoch}';
    final scheduleTimes =
        times ??
        (firstDoseAt == null
            ? const <int>[]
            : [firstDoseAt.hour * 60 + firstDoseAt.minute]);
    final medication = Medication(
      id: id,
      name: name.trim(),
      strength: strength.trim(),
      form: form,
      doseLabel: doseLabel.trim(),
      instructions: instructions.trim(),
      colorSeed: _colorCursor++,
      isPrescription: isPrescription,
      activeIngredients: _normalizeActiveIngredients(activeIngredients),
      schedule: MedicationSchedule(
        times: scheduleTimes,
        startDate: startDate ?? firstDoseAt ?? today,
        durationDays: durationDays,
      ),
    );
    _medications.add(medication);
    _materializeMedication(medication);
    _changed();
    return medication;
  }

  /// Saves edits. When reminder times or the course change, untouched future
  /// reminders are rebuilt; recorded history is never rewritten.
  void updateMedication(Medication updated) {
    final index = _medications.indexWhere((item) => item.id == updated.id);
    if (index == -1) return;
    _medications[index] = updated.copyWith(
      activeIngredients: _normalizeActiveIngredients(updated.activeIngredients),
    );
    final current = now;
    _doses.removeWhere((dose) {
      final remove =
          dose.medicationId == updated.id &&
          dose.status == DoseStatus.scheduled &&
          dose.originalScheduledAt == null &&
          dose.scheduledAt.isAfter(current);
      if (remove) _doseIds.remove(dose.id);
      return remove;
    });
    _materializeMedication(_medications[index], from: current);
    _changed();
  }

  void removeMedication(String id) {
    final doseIds = {
      for (final dose in _doses)
        if (dose.medicationId == id) dose.id,
    };
    _medications.removeWhere((item) => item.id == id);
    _doses.removeWhere((dose) => doseIds.contains(dose.id));
    _doseIds.removeAll(doseIds);
    _events.removeWhere((event) => doseIds.contains(event.doseId));
    if (doseIds.contains(_pendingProposal?.doseId)) _pendingProposal = null;
    _changed();
  }

  /// Adds the sample plan so a new user can explore before entering their own.
  void loadSamplePlan() {
    _addSampleMedications();
    _materializeWindow(force: true);
    _changed();
  }

  List<String> _normalizeActiveIngredients(List<String> ingredients) {
    final seen = <String>{};
    return [
      for (final ingredient in ingredients)
        if (ingredient.trim().isNotEmpty &&
            seen.add(ingredient.trim().toLowerCase()))
          ingredient.trim(),
    ];
  }

  void _addSampleMedications() {
    for (final medication in DemoData.medicationsStarting(today)) {
      if (medicationOrNull(medication.id) != null) continue;
      _medications.add(medication);
      _colorCursor = _colorCursor > medication.colorSeed
          ? _colorCursor
          : medication.colorSeed + 1;
    }
  }

  // ---------------------------------------------------------------------------
  // Assistant

  void addMessage(ChatMessage message) {
    _messages.add(message);
    if (_messages.length > 200) {
      _messages.removeRange(0, _messages.length - 200);
    }
    _changed();
  }

  void clearConversation() {
    _messages.clear();
    _pendingProposal = null;
    _changed();
  }

  void setRemoteAiConsent(bool? value) {
    _remoteAiConsent = value;
    _changed();
  }

  void acceptVoiceNotice() {
    _voiceNoticeAccepted = true;
    _changed();
  }

  void applyAssistantEffects({
    List<MedicationMemoryFact> memoryUpdates = const [],
    AssistantDoseEvent? doseEvent,
    RescheduleProposal? scheduleProposal,
  }) {
    _mergeMemoryFacts(memoryUpdates);
    final event = doseEvent;
    if (event != null &&
        event.confidence == AssistantConfidence.high &&
        event.doseId != null) {
      final index = _doses.indexWhere((dose) => dose.id == event.doseId);
      if (index != -1) {
        final dose = _doses[index];
        final at = event.occurredAt ?? now;
        switch (event.action) {
          case AssistantDoseAction.taken:
            _doses[index] = dose.copyWith(
              status: DoseStatus.taken,
              actualAt: at,
            );
            _recordEvent(
              DoseEvent(
                doseId: dose.id,
                type: DoseStatus.taken,
                recordedAt: at,
                note: event.note ?? 'Recorded from AI chat',
              ),
            );
          case AssistantDoseAction.missed:
            _doses[index] = dose.copyWith(
              status: DoseStatus.missed,
              missedReason: event.note ?? 'Reported in AI chat',
            );
            _recordEvent(
              DoseEvent(
                doseId: dose.id,
                type: DoseStatus.missed,
                recordedAt: at,
                note: event.note ?? 'Reported in AI chat',
              ),
            );
          case AssistantDoseAction.snoozed:
            _recordEvent(
              DoseEvent(
                doseId: dose.id,
                type: DoseStatus.snoozed,
                recordedAt: at,
                note: event.note ?? 'Snooze reported in AI chat',
              ),
            );
          case AssistantDoseAction.none:
            break;
        }
      }
    }
    if (scheduleProposal != null) _pendingProposal = scheduleProposal;
    _changed();
  }

  void _mergeMemoryFacts(List<MedicationMemoryFact> updates) {
    for (final update in updates) {
      final normalized = update.value.trim().toLowerCase();
      final existing = _memoryFacts.indexWhere(
        (fact) =>
            fact.kind == update.kind &&
            fact.value.trim().toLowerCase() == normalized,
      );
      if (existing == -1) {
        _memoryFacts.add(update);
      } else {
        _memoryFacts[existing] = update;
      }
    }
    if (_memoryFacts.length > 120) {
      _memoryFacts.removeRange(0, _memoryFacts.length - 120);
    }
  }

  // ---------------------------------------------------------------------------
  // Profile and settings

  void updateProfile(CareProfile updatedProfile) {
    profile = updatedProfile;
    _changed();
  }

  void updateSafetyContext(SafetyContext updatedContext) {
    safetyContext = updatedContext.copyWith(lastReviewedAt: now);
    _changed();
  }

  void setDisplayMode(AppDisplayMode mode) {
    if (_displayMode == mode) return;
    _displayMode = mode;
    _changed();
  }

  void setLanguage(AppLanguage value) {
    if (language == value) return;
    profile = profile.copyWith(preferredLanguage: value.profileValue);
    _changed();
  }

  void completeOnboarding({
    required String name,
    required AppLanguage language,
  }) {
    profile = profile.copyWith(
      name: name.trim(),
      preferredLanguage: language.profileValue,
    );
    _onboardingComplete = true;
    _changed();
  }

  /// Deletes every saved record and returns to onboarding.
  Future<void> resetAll() async {
    _medications.clear();
    _doses.clear();
    _doseIds.clear();
    _events.clear();
    _messages.clear();
    _memoryFacts.clear();
    _pendingProposal = null;
    _remoteAiConsent = null;
    _voiceNoticeAccepted = false;
    _displayMode = AppDisplayMode.standard;
    _colorCursor = 0;
    safetyContext = const SafetyContext();
    profile = CareProfile(
      name: '',
      conditions: const ['No conditions recorded'],
      allergies: const ['No allergies recorded'],
      wakeTimeLabel: '7:00 AM',
      sleepTimeLabel: '11:00 PM',
      preferredLanguage: profile.preferredLanguage,
    );
    _onboardingComplete = false;
    await _pendingWrite;
    try {
      await _storage?.clear();
    } catch (_) {
      // Nothing more can be done; the in-memory state is already cleared.
    }
    notifyListeners();
  }

  /// Called by the app shell about every 30 seconds so "due now" and the
  /// calendar day stay current without a restart.
  void tick() {
    final current = now;
    final minute = current.hour * 60 + current.minute;
    if (minute == _lastTickMinute) return;
    _lastTickMinute = minute;
    _materializeWindow();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Reminder generation

  void _materializeWindow({bool force = false}) {
    final day = today;
    if (!force && _windowDay == day) return;
    _windowDay = day;
    for (final medication in _medications) {
      _materializeMedication(medication);
    }
  }

  void _materializeMedication(Medication medication, {DateTime? from}) {
    final schedule = medication.schedule;
    if (schedule == null || schedule.isAsNeeded) return;
    final day = today;
    var cursor = DateTime(day.year, day.month, day.day - _windowPastDays);
    final last = DateTime(day.year, day.month, day.day + _windowFutureDays);
    if (cursor.isBefore(schedule.startDate)) cursor = schedule.startDate;
    while (!cursor.isAfter(last)) {
      if (!schedule.isActiveOn(cursor)) {
        if (schedule.endDate != null && cursor.isAfter(schedule.endDate!)) {
          break;
        }
      } else {
        for (final minutes in schedule.times) {
          final at = DateTime(
            cursor.year,
            cursor.month,
            cursor.day,
            minutes ~/ 60,
            minutes % 60,
          );
          if (from != null && !at.isAfter(from)) continue;
          final id = doseIdFor(medication.id, cursor, minutes);
          if (_doseIds.contains(id)) continue;
          _doseIds.add(id);
          _doses.add(
            DoseOccurrence(
              id: id,
              medicationId: medication.id,
              scheduledAt: at,
              status: DoseStatus.scheduled,
            ),
          );
        }
      }
      cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
    }
  }

  static String doseIdFor(String medicationId, DateTime day, int minutes) {
    final date =
        '${day.year}${day.month.toString().padLeft(2, '0')}${day.day.toString().padLeft(2, '0')}';
    return 'dose-$medicationId-$date-$minutes';
  }

  bool _isOpen(DoseOccurrence dose) =>
      dose.status == DoseStatus.due ||
      dose.status == DoseStatus.scheduled ||
      dose.status == DoseStatus.snoozed ||
      dose.status == DoseStatus.adjusted;

  void _recordEvent(DoseEvent event) {
    _events.add(event);
    if (_events.length > _maxEvents) {
      _events.removeRange(0, _events.length - _maxEvents);
    }
  }

  void _replaceDose(DoseOccurrence replacement) {
    final index = _doses.indexWhere((dose) => dose.id == replacement.id);
    if (index != -1) _doses[index] = replacement;
  }

  // ---------------------------------------------------------------------------
  // Persistence

  void _changed() {
    notifyListeners();
    _save();
  }

  void _save() {
    final storage = _storage;
    if (storage == null || !_isLoaded) return;
    final encoded = jsonEncode(_snapshot());
    _pendingWrite = _pendingWrite
        .then((_) => storage.write(encoded))
        .catchError((Object _) {
          // Storage failures must never break dose logging in the UI.
        });
  }

  Map<String, Object?> _snapshot() {
    final oldest = DateTime(
      today.year,
      today.month,
      today.day - _keepHistoryDays,
    );
    final savedMessages = _messages.length > _maxSavedMessages
        ? _messages.sublist(_messages.length - _maxSavedMessages)
        : _messages;
    return {
      'version': StoreSnapshotCodec.version,
      'onboarded': _onboardingComplete,
      'displayMode': _displayMode.name,
      'remoteAiConsent': _remoteAiConsent,
      'voiceNoticeAccepted': _voiceNoticeAccepted,
      'colorCursor': _colorCursor,
      'profile': StoreSnapshotCodec.profile(profile),
      'safetyContext': StoreSnapshotCodec.safetyContext(safetyContext),
      'memoryFacts': [
        for (final fact in _memoryFacts) StoreSnapshotCodec.memoryFact(fact),
      ],
      'medications': [
        for (final medication in _medications)
          StoreSnapshotCodec.medication(medication),
      ],
      'doses': [
        for (final dose in _doses)
          // Untouched future reminders are regenerated, so only history and
          // changed reminders need saving.
          if (!dose.scheduledAt.isBefore(oldest) &&
              (dose.status != DoseStatus.scheduled ||
                  dose.originalScheduledAt != null ||
                  !dose.scheduledAt.isAfter(now)))
            StoreSnapshotCodec.dose(dose),
      ],
      'events': [for (final event in _events) StoreSnapshotCodec.event(event)],
      'messages': [
        for (final message in savedMessages)
          StoreSnapshotCodec.message(message),
      ],
    };
  }

  Future<void> _load() async {
    try {
      final raw = await _storage?.read();
      if (raw != null && raw.trim().isNotEmpty) _restore(raw);
    } catch (_) {
      // A corrupt snapshot falls back to a fresh start rather than a crash.
    }
    _isLoaded = true;
    _materializeWindow(force: true);
    if (!_ready.isCompleted) _ready.complete();
    notifyListeners();
  }

  void _restore(String encoded) {
    final decoded = jsonDecode(encoded);
    if (decoded is! Map) return;
    final root = decoded.cast<String, Object?>();
    profile =
        StoreSnapshotCodec.decodeProfile(root['profile'], profile) ?? profile;
    safetyContext =
        StoreSnapshotCodec.decodeSafetyContext(root['safetyContext']) ??
        safetyContext;
    _onboardingComplete = root['onboarded'] == true;
    _displayMode = AppDisplayMode.values.firstWhere(
      (mode) => mode.name == root['displayMode'],
      orElse: () => AppDisplayMode.standard,
    );
    final consent = root['remoteAiConsent'];
    _remoteAiConsent = consent is bool ? consent : null;
    _voiceNoticeAccepted = root['voiceNoticeAccepted'] == true;
    _colorCursor = root['colorCursor'] is int ? root['colorCursor'] as int : 0;
    _memoryFacts
      ..clear()
      ..addAll(
        StoreSnapshotCodec.decodeList(
          root['memoryFacts'],
          StoreSnapshotCodec.decodeMemoryFact,
        ),
      );
    _medications
      ..clear()
      ..addAll(
        StoreSnapshotCodec.decodeList(
          root['medications'],
          StoreSnapshotCodec.decodeMedication,
        ),
      );
    final knownMedications = {for (final item in _medications) item.id};
    _doses.clear();
    _doseIds.clear();
    for (final dose in StoreSnapshotCodec.decodeList(
      root['doses'],
      StoreSnapshotCodec.decodeDose,
    )) {
      if (!knownMedications.contains(dose.medicationId)) continue;
      if (_doseIds.add(dose.id)) _doses.add(dose);
    }
    _events
      ..clear()
      ..addAll(
        StoreSnapshotCodec.decodeList(
          root['events'],
          StoreSnapshotCodec.decodeEvent,
        ),
      );
    _messages
      ..clear()
      ..addAll(
        StoreSnapshotCodec.decodeList(
          root['messages'],
          StoreSnapshotCodec.decodeMessage,
        ),
      );
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
