import 'package:flutter/material.dart';

import '../../domain/app_models.dart';
import '../../domain/app_store.dart';
import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';

/// Two short steps: pick a language, then say hello and accept the basics.
/// Every disclaimer the old screens repeated lives here, once.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({required this.store, super.key});

  final AppStore store;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _name = TextEditingController();
  int _step = 0;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: AppDurations.regular,
          child: _step == 0 ? _welcome(context) : _about(context),
        ),
      ),
    );
  }

  Widget _welcome(BuildContext context) {
    final s = AppStrings.of(context);
    final text = Theme.of(context).textTheme;
    return LayoutBuilder(
      key: const ValueKey('welcome'),
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 2),
                const Center(child: PillAiMark(size: 104)),
                const SizedBox(height: 24),
                Text(
                  s.appName,
                  textAlign: TextAlign.center,
                  style: text.displaySmall,
                ),
                const SizedBox(height: 10),
                Text(
                  s.tagline,
                  textAlign: TextAlign.center,
                  style: text.headlineSmall?.copyWith(
                    color: AppColors.inkMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(flex: 3),
                Text(
                  s.chooseLanguage,
                  textAlign: TextAlign.center,
                  style: text.labelLarge?.copyWith(color: AppColors.inkSubtle),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final language in const [
                      AppLanguage.arabic,
                      AppLanguage.english,
                    ]) ...[
                      Expanded(
                        child: _LanguageCard(
                          label: s.languageName(language),
                          selected: widget.store.language == language,
                          onTap: () => widget.store.setLanguage(language),
                        ),
                      ),
                      if (language == AppLanguage.arabic)
                        const SizedBox(width: 12),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => setState(() => _step = 1),
                  child: Text(s.getStarted),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _about(BuildContext context) {
    final s = AppStrings.of(context);
    final text = Theme.of(context).textTheme;
    return LayoutBuilder(
      key: const ValueKey('about'),
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                    onPressed: () => setState(() => _step = 0),
                    icon: const BackButtonIcon(),
                  ),
                ),
                const SizedBox(height: 8),
                Text(s.whatsYourName, style: text.headlineMedium),
                const SizedBox(height: 14),
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    hintText: s.nameOptional,
                    prefixIcon: const Icon(Icons.person_rounded),
                  ),
                ),
                const SizedBox(height: 32),
                _Promise(
                  icon: Icons.calendar_today_rounded,
                  color: AppColors.primary,
                  text: s.promisePlan,
                ),
                _Promise(
                  icon: Icons.auto_awesome_rounded,
                  color: AppColors.ai,
                  text: s.promiseAi,
                ),
                _Promise(
                  icon: Icons.verified_user_rounded,
                  color: AppColors.primary,
                  text: s.promiseDose,
                ),
                const Spacer(),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.inkMuted,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          s.onboardingDisclaimer,
                          style: text.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () => widget.store.completeOnboarding(
                    name: _name.text,
                    language: widget.store.language,
                  ),
                  child: Text(s.agreeAndStart),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.primarySoft : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: SizedBox(
            height: 58,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (selected) ...[
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: selected ? AppColors.primaryDark : AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Promise extends StatelessWidget {
  const _Promise({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withAlpha(26),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.titleMedium),
          ),
        ],
      ),
    );
  }
}
