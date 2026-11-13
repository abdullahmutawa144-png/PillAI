import 'package:flutter/material.dart';

import '../../domain/app_models.dart';
import '../../domain/app_store.dart';
import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import 'dose_sheets.dart';
import 'safety_profile_screen.dart';

/// Converts a stored routine label such as "7:00 AM" to minutes after midnight.
int? parseTimeLabel(String label) {
  final match = RegExp(
    r'^\s*(\d{1,2}):(\d{2})\s*([AaPp][Mm])?\s*$',
  ).firstMatch(label);
  if (match == null) return null;
  var hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  final suffix = match.group(3)?.toUpperCase();
  if (suffix == 'PM' && hour < 12) hour += 12;
  if (suffix == 'AM' && hour == 12) hour = 0;
  if (hour > 23 || minute > 59) return null;
  return hour * 60 + minute;
}

/// Routine labels are stored in one English format so the backend always sees
/// the same shape, whatever language the screen is in.
String canonicalTimeLabel(int minutes) {
  final hour24 = minutes ~/ 60;
  final hour = hour24 % 12 == 0 ? 12 : hour24 % 12;
  return '$hour:${(minutes % 60).toString().padLeft(2, '0')} ${hour24 < 12 ? 'AM' : 'PM'}';
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({required this.store, super.key});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final s = AppStrings.of(context);
        final text = Theme.of(context).textTheme;
        final profile = store.profile;
        final safety = store.safetyContext;
        final consent = store.remoteAiConsent;

        return SafeArea(
          bottom: false,
          child: ListView(
            key: const PageStorageKey('profile-scroll'),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            children: [
              Semantics(
                header: true,
                child: Text(s.profileTitle, style: text.headlineLarge),
              ),
              const SizedBox(height: 18),
              _ProfileCard(
                name: profile.name,
                subtitle: s.medicineCount(store.medications.length),
                onEdit: () => _editName(context),
              ),
              const SizedBox(height: 24),
              SettingsGroup(
                title: s.sectionHealth,
                children: [
                  SettingsTile(
                    icon: Icons.health_and_safety_rounded,
                    title: s.healthProfile,
                    value: s.healthProgress(
                      safety.reviewedAreaCount,
                      safety.totalAreaCount,
                    ),
                    onTap: () => openHealthProfile(context, store),
                  ),
                  SettingsTile(
                    icon: Icons.wb_twilight_rounded,
                    title: s.dailyRoutine,
                    value:
                        '${_label(s, profile.wakeTimeLabel)} – ${_label(s, profile.sleepTimeLabel)}',
                    onTap: () => _editRoutine(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SettingsGroup(
                title: s.sectionApp,
                children: [
                  SettingsTile(
                    icon: Icons.translate_rounded,
                    title: s.languageLabel,
                    value: s.languageName(store.language),
                    onTap: () => _pickLanguage(context),
                  ),
                  SettingsTile(
                    icon: Icons.text_increase_rounded,
                    title: s.simpleMode,
                    onTap: () => store.setDisplayMode(
                      store.isSimpleMode
                          ? AppDisplayMode.standard
                          : AppDisplayMode.simple,
                    ),
                    trailing: Switch.adaptive(
                      value: store.isSimpleMode,
                      onChanged: (value) => store.setDisplayMode(
                        value ? AppDisplayMode.simple : AppDisplayMode.standard,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SettingsGroup(
                title: s.sectionPrivacy,
                children: [
                  SettingsTile(
                    icon: Icons.auto_awesome_rounded,
                    iconColor: AppColors.ai,
                    title: s.smartAnswers,
                    value: consent == null
                        ? s.askMe
                        : consent
                        ? s.on
                        : s.off,
                    onTap: () => _editSmartAnswers(context),
                  ),
                  SettingsTile(
                    icon: Icons.verified_user_rounded,
                    title: s.howPillAiKeepsYouSafe,
                    onTap: () => _showSafety(context),
                  ),
                  SettingsTile(
                    icon: Icons.emergency_rounded,
                    iconColor: AppColors.danger,
                    title: s.emergencyNumbers,
                    onTap: () => showEmergencySheet(context),
                  ),
                  SettingsTile(
                    icon: Icons.delete_forever_rounded,
                    destructive: true,
                    title: s.deleteAllData,
                    onTap: () => _confirmReset(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Center(child: Text('PillAI 1.0', style: text.bodySmall)),
            ],
          ),
        );
      },
    );
  }

  String _label(AppStrings s, String stored) {
    final minutes = parseTimeLabel(stored);
    return minutes == null ? stored : s.compactTimeOfMinutes(minutes);
  }

  Future<void> _editName(BuildContext context) async {
    final s = AppStrings.of(context);
    final controller = TextEditingController(text: store.profile.name);
    final name = await showAppSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetHeader(title: s.yourName),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                onSubmitted: (value) => Navigator.pop(sheetContext, value),
                decoration: InputDecoration(hintText: s.nameOptional),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(sheetContext, controller.text),
                child: Text(s.save),
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
    if (name != null) {
      store.updateProfile(store.profile.copyWith(name: name.trim()));
    }
  }

  Future<void> _editRoutine(BuildContext context) async {
    await showAppSheet<void>(
      context: context,
      builder: (sheetContext) => AnimatedBuilder(
        animation: store,
        builder: (sheetContext, _) {
          final s = AppStrings.of(sheetContext);
          final profile = store.profile;
          Future<void> pick({required bool wake}) async {
            final current =
                parseTimeLabel(
                  wake ? profile.wakeTimeLabel : profile.sleepTimeLabel,
                ) ??
                (wake ? 7 * 60 : 23 * 60);
            final picked = await showTimePicker(
              context: sheetContext,
              initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
            );
            if (picked == null) return;
            final label = canonicalTimeLabel(picked.hour * 60 + picked.minute);
            store.updateProfile(
              wake
                  ? profile.copyWith(wakeTimeLabel: label)
                  : profile.copyWith(sleepTimeLabel: label),
            );
          }

          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SheetHeader(title: s.dailyRoutine),
                  const SizedBox(height: 16),
                  SettingsGroup(
                    children: [
                      SettingsTile(
                        icon: Icons.wb_sunny_rounded,
                        iconColor: AppColors.amber,
                        title: s.wakeUp,
                        value: _label(s, profile.wakeTimeLabel),
                        onTap: () => pick(wake: true),
                      ),
                      SettingsTile(
                        icon: Icons.bedtime_rounded,
                        iconColor: AppColors.ai,
                        title: s.sleep,
                        value: _label(s, profile.sleepTimeLabel),
                        onTap: () => pick(wake: false),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickLanguage(BuildContext context) async {
    final s = AppStrings.of(context);
    final picked = await showAppSheet<AppLanguage>(
      context: context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetHeader(title: s.languageLabel),
              const SizedBox(height: 16),
              SettingsGroup(
                children: [
                  for (final language in AppLanguage.values)
                    SettingsTile(
                      icon: Icons.translate_rounded,
                      title: s.languageName(language),
                      onTap: () => Navigator.pop(sheetContext, language),
                      trailing: store.language == language
                          ? const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.primary,
                            )
                          : const SizedBox(width: 24),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) store.setLanguage(picked);
  }

  Future<void> _editSmartAnswers(BuildContext context) {
    return showAppSheet<void>(
      context: context,
      builder: (sheetContext) => AnimatedBuilder(
        animation: store,
        builder: (sheetContext, _) {
          final s = AppStrings.of(sheetContext);
          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SheetHeader(
                    leading: const PillAiMark(size: 44),
                    title: s.smartAnswers,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    s.smartAnswersBody,
                    style: Theme.of(sheetContext).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: store.remoteAiConsent == true,
                    title: Text(s.smartAnswers),
                    onChanged: store.setRemoteAiConsent,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showSafety(BuildContext context) {
    return showAppSheet<void>(
      context: context,
      builder: (sheetContext) {
        final s = AppStrings.of(sheetContext);
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SheetHeader(
                  leading: const PillAiMark(size: 44),
                  title: s.howPillAiKeepsYouSafe,
                ),
                const SizedBox(height: 16),
                for (final promise in s.safetyPromises)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check_circle_outline_rounded,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            promise,
                            style: Theme.of(sheetContext).textTheme.bodyLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final s = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.deleteAllData),
        content: Text(s.deleteAllDataBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) await store.resetAll();
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.name,
    required this.subtitle,
    required this.onEdit,
  });

  final String name;
  final String subtitle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final text = Theme.of(context).textTheme;
    final trimmed = name.trim();
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  gradient: AppGradients.hero,
                  shape: BoxShape.circle,
                ),
                child: trimmed.isEmpty
                    ? const Icon(Icons.person_rounded, color: Colors.white)
                    : Text(
                        trimmed.characters.first.toUpperCase(),
                        style: text.headlineSmall?.copyWith(
                          color: Colors.white,
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trimmed.isEmpty ? s.yourName : trimmed,
                      style: text.titleLarge?.copyWith(
                        color: trimmed.isEmpty
                            ? AppColors.inkSubtle
                            : AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: text.bodyMedium),
                  ],
                ),
              ),
              Icon(
                Icons.edit_rounded,
                color: AppColors.inkSubtle,
                semanticLabel: s.edit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
