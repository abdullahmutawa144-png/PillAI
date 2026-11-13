import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/device_voice_input.dart';
import 'data/http_assistant_gateway.dart';
import 'data/preferences_state_storage.dart';
import 'domain/app_models.dart';
import 'domain/app_store.dart';
import 'domain/assistant_gateway.dart';
import 'domain/voice_input.dart';
import 'presentation/l10n/app_strings.dart';
import 'presentation/screens/add_medication_sheet.dart';
import 'presentation/screens/assistant_screen.dart';
import 'presentation/screens/medications_screen.dart';
import 'presentation/screens/onboarding_screen.dart';
import 'presentation/screens/profile_screen.dart';
import 'presentation/screens/safety_profile_screen.dart';
import 'presentation/screens/today_screen.dart';
import 'presentation/theme/app_theme.dart';
import 'presentation/widgets/widgets.dart';

class PillAiApp extends StatefulWidget {
  const PillAiApp({
    this.store,
    this.voiceInput,
    this.assistantGateway,
    super.key,
  });

  /// Optional dependencies keep device services out of widget tests.
  final AppStore? store;
  final VoiceInputController? voiceInput;
  final AssistantGateway? assistantGateway;

  @override
  State<PillAiApp> createState() => _PillAiAppState();
}

class _PillAiAppState extends State<PillAiApp> with WidgetsBindingObserver {
  late final AppStore _store;
  late final VoiceInputController _voiceInput;
  late final AssistantGateway _assistantGateway;
  late final bool _ownsStore;
  late final bool _ownsVoiceInput;
  late final bool _ownsAssistantGateway;
  late (bool, bool, AppLanguage, AppDisplayMode) _appShape;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ownsStore = widget.store == null;
    _ownsVoiceInput = widget.voiceInput == null;
    _ownsAssistantGateway = widget.assistantGateway == null;
    final deviceLanguage =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode == 'ar'
        ? AppLanguage.arabic
        : AppLanguage.english;
    _store =
        widget.store ??
        AppStore.persistent(
          storage: PreferencesStateStorage(),
          initialLanguage: deviceLanguage,
        );
    _voiceInput = widget.voiceInput ?? DeviceVoiceInput();
    _assistantGateway =
        widget.assistantGateway ??
        ResilientAssistantGateway(
          // Supplying a store is the widget-test injection path. Tests stay
          // deterministic unless they explicitly inject a gateway.
          remote: widget.store == null
              ? HttpAssistantGateway.fromEnvironment()
              : null,
        );
    _appShape = _shapeOf(_store);
    _store.addListener(_onStoreChanged);
  }

  // Only app-wide changes rebuild MaterialApp; screens listen to the store.
  (bool, bool, AppLanguage, AppDisplayMode) _shapeOf(AppStore store) => (
    store.isLoaded,
    store.onboardingComplete,
    store.language,
    store.displayMode,
  );

  void _onStoreChanged() {
    final shape = _shapeOf(_store);
    if (shape != _appShape) setState(() => _appShape = shape);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _store.tick();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_voiceInput.cancel());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _store.removeListener(_onStoreChanged);
    if (_ownsVoiceInput) _voiceInput.dispose();
    if (_ownsAssistantGateway &&
        _assistantGateway is DisposableAssistantGateway) {
      (_assistantGateway as DisposableAssistantGateway).dispose();
    }
    if (_ownsStore) _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (loaded, onboarded, language, mode) = _appShape;
    return MaterialApp(
      title: 'PillAI',
      debugShowCheckedModeBanner: false,
      locale: Locale(language.code),
      supportedLocales: AppStrings.supportedLocales,
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.build(
        simple: mode == AppDisplayMode.simple,
        arabic: language == AppLanguage.arabic,
      ),
      home: !loaded
          ? const _Splash()
          : !onboarded
          ? OnboardingScreen(store: _store)
          : AppShell(
              store: _store,
              voiceInput: _voiceInput,
              assistantGateway: _assistantGateway,
            ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: PillAiMark(size: 80)));
  }
}

class AppShell extends StatefulWidget {
  const AppShell({
    required this.store,
    required this.voiceInput,
    required this.assistantGateway,
    super.key,
  });

  final AppStore store;
  final VoiceInputController voiceInput;
  final AssistantGateway assistantGateway;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _assistantTab = 1;

  int _selectedIndex = 0;
  int _voiceRequest = 0;
  String? _prompt;
  String? _draft;
  Timer? _ticker;

  AppStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    // Keeps "due now" and the calendar day current while the app stays open.
    if (store.usesLiveClock) {
      _ticker = Timer.periodic(
        const Duration(seconds: 30),
        (_) => store.tick(),
      );
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Opens the assistant. A prompt ending in ":" is placed in the composer
  /// for the user to finish; any other prompt is sent right away.
  void _openAssistant(String? prompt) {
    setState(() {
      _prompt = null;
      _draft = null;
      if (prompt != null && prompt.trimRight().endsWith(':')) {
        _draft = prompt;
      } else {
        _prompt = prompt;
      }
      _selectedIndex = _assistantTab;
    });
  }

  void _startVoice() {
    setState(() {
      _prompt = null;
      _draft = null;
      _voiceRequest++;
      _selectedIndex = _assistantTab;
    });
  }

  void _select(int index) {
    if (_selectedIndex == _assistantTab && index != _assistantTab) {
      unawaited(widget.voiceInput.cancel());
    }
    setState(() => _selectedIndex = index);
  }

  void _navigate(AssistantDestination destination) {
    switch (destination) {
      case AssistantDestination.today:
        _select(0);
      case AssistantDestination.medicines:
        _select(2);
      case AssistantDestination.healthProfile:
        unawaited(openHealthProfile(context, store));
    }
  }

  Future<void> _addMedicine() async {
    if (_selectedIndex == _assistantTab) unawaited(widget.voiceInput.cancel());
    final added = await showMedicationEditor(context, store: store);
    if (!mounted || added != true || store.medications.isEmpty) return;
    final s = AppStrings.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.addedSnack(store.medications.last.name))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          TodayScreen(
            store: store,
            onOpenAssistant: _openAssistant,
            onStartVoice: _startVoice,
            onAddMedicine: _addMedicine,
            onOpenProfile: () => _select(3),
          ),
          AssistantScreen(
            store: store,
            voiceInput: widget.voiceInput,
            assistantGateway: widget.assistantGateway,
            voiceRequestId: _voiceRequest,
            initialPrompt: _prompt,
            initialDraft: _draft,
            onPromptConsumed: () {
              _prompt = null;
              _draft = null;
            },
            onNavigate: _navigate,
          ),
          MedicationsScreen(
            store: store,
            onAddMedicine: _addMedicine,
            onAsk: _openAssistant,
          ),
          ProfileScreen(store: store),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _select,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.today_outlined),
              selectedIcon: const Icon(Icons.today_rounded),
              label: s.tabToday,
            ),
            NavigationDestination(
              icon: const Icon(Icons.auto_awesome_outlined),
              selectedIcon: const Icon(Icons.auto_awesome_rounded),
              label: s.tabAssistant,
            ),
            NavigationDestination(
              icon: const Icon(Icons.medication_outlined),
              selectedIcon: const Icon(Icons.medication_rounded),
              label: s.tabMedicines,
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline_rounded),
              selectedIcon: const Icon(Icons.person_rounded),
              label: s.tabProfile,
            ),
          ],
        ),
      ),
    );
  }
}
