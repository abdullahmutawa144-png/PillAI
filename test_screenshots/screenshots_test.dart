// Renders every main screen to PNG for design review.
//
// Run: flutter test test_screenshots
// Output: build/screenshots/<language>/<nn-name>.png
//
// It lives outside test/ so the regular suite stays fast. Fonts are loaded
// from the Flutter SDK (Roboto, Material Icons) and, for Arabic glyphs, from
// the local Windows font folder when it exists. Nothing here ships in the app.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pill_ai/app.dart';
import 'package:pill_ai/domain/app_models.dart';
import 'package:pill_ai/domain/app_store.dart';
import 'package:pill_ai/domain/assistant_gateway.dart';
import 'package:pill_ai/domain/state_storage.dart';
import 'package:pill_ai/domain/voice_input.dart';

const _size = Size(390, 844);
const _pixelRatio = 2.0;
final _clock = DateTime(2026, 10, 1, 14, 20);

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  var added = false;
  for (final path in paths) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final bytes = file.readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    added = true;
  }
  if (added) await loader.load();
}

String get _flutterRoot {
  final fromEnv = Platform.environment['FLUTTER_ROOT'];
  if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
  return r'C:\Flutter\flutter';
}

Future<void> _loadFonts() async {
  final material = '$_flutterRoot/bin/cache/artifacts/material_fonts';
  await _loadFont('Roboto', [
    '$material/roboto-regular.ttf',
    '$material/roboto-medium.ttf',
    '$material/roboto-bold.ttf',
    '$material/roboto-black.ttf',
  ]);
  await _loadFont('MaterialIcons', ['$material/materialicons-regular.otf']);
  await _loadFont('Segoe UI', [
    r'C:\Windows\Fonts\segoeui.ttf',
    r'C:\Windows\Fonts\segoeuisb.ttf',
    r'C:\Windows\Fonts\segoeuib.ttf',
  ]);
}

Future<void> _capture(WidgetTester tester, String language, String name) async {
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('screenshot-root')),
  );
  await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: _pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/screenshots/$language/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(data!.buffer.asUint8List());
  });
}

Future<void> _pump(WidgetTester tester, AppStore store) async {
  tester.view.physicalSize = _size * _pixelRatio;
  tester.view.devicePixelRatio = _pixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey('screenshot-root'),
      child: PillAiApp(
        store: store,
        voiceInput: _IdleVoice(),
        assistantGateway: _OfflineGateway(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(_loadFonts);

  for (final language in AppLanguage.values) {
    final ar = language == AppLanguage.arabic;
    final code = language.code;

    testWidgets('onboarding ($code)', (tester) async {
      final store = AppStore.persistent(
        storage: InMemoryStateStorage(),
        clock: () => _clock,
        initialLanguage: language,
      );
      await _pump(tester, store);
      await _capture(tester, code, '01-welcome');
      await _tapText(tester, ar ? 'ابدأ' : 'Get started');
      await _capture(tester, code, '02-about-you');
      await _tapText(tester, ar ? 'موافق، لنبدأ' : 'Agree & start');
      await _capture(tester, code, '03-empty-today');
    });

    testWidgets('main screens ($code)', (tester) async {
      final store = AppStore.demo(clock: _clock)..setLanguage(language);
      store.updateProfile(store.profile.copyWith(name: ar ? 'عمر' : 'Omar'));
      store.markTaken(
        store.todayDoses.first.id,
        at: DateTime(2026, 10, 1, 10, 6),
      );
      await _pump(tester, store);
      await _capture(tester, code, '04-today');

      await tester.tap(find.byType(NavigationDestination).at(1));
      await tester.pumpAndSettle();
      await _capture(tester, code, '05-assistant');

      await tester.enterText(
        find.byType(TextField),
        ar
            ? 'شربت شاي الحين، هل يأثر على الحديد؟'
            : 'I just had tea. Does it affect my iron?',
      );
      await tester.pump();
      await tester.tap(find.byTooltip(ar ? 'إرسال' : 'Send message'));
      await tester.pumpAndSettle();
      await _capture(tester, code, '06-assistant-answer');

      await tester.tap(find.byType(NavigationDestination).at(2));
      await tester.pumpAndSettle();
      await _capture(tester, code, '07-medicines');

      await _tapText(tester, ar ? 'إضافة' : 'Add');
      await _capture(tester, code, '08-add-medicine');
      await tester.tapAt(const Offset(195, 12));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(NavigationDestination).at(3));
      await tester.pumpAndSettle();
      await _capture(tester, code, '09-profile');

      await _tapText(tester, ar ? 'ملفي الصحي' : 'Health profile');
      await _capture(tester, code, '10-health-profile');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(NavigationDestination).at(0));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Magnesium').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Magnesium').last);
      await tester.pumpAndSettle();
      await _capture(tester, code, '11-dose-sheet');
      await tester.tapAt(const Offset(195, 12));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(NavigationDestination).at(1));
      await tester.pumpAndSettle();
      await _tapText(tester, ar ? 'طوارئ' : 'Emergency');
      await _capture(tester, code, '12-emergency');
    });

    testWidgets('simple mode ($code)', (tester) async {
      final store = AppStore.demo(clock: _clock)
        ..setLanguage(language)
        ..setDisplayMode(AppDisplayMode.simple);
      await _pump(tester, store);
      await _capture(tester, code, '13-simple-today');
    });
  }
}

class _OfflineGateway implements AssistantGateway {
  @override
  Future<AssistantGatewayResponse> replyTo(
    String message,
    AppStore store, {
    List<ChatMessage> history = const [],
  }) {
    throw const AssistantGatewayException(
      AssistantFallbackReason.network,
      'offline for screenshots',
    );
  }
}

class _IdleVoice extends VoiceInputController {
  @override
  String? get errorMessage => null;

  @override
  double get soundLevel => 0;

  @override
  VoiceInputStatus get status => VoiceInputStatus.idle;

  @override
  Future<void> cancel() async {}

  @override
  Future<bool> initialize() async => true;

  @override
  Future<void> start({
    required ValueChanged<VoiceTranscript> onTranscript,
    String? localeId,
  }) async {}

  @override
  Future<void> stop() async {}
}
