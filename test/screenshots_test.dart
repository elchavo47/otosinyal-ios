// Arayüz ekran görüntüleri (yalnız CI'da, isteğe bağlı).
//
// Çalıştırma: flutter test test/screenshots_test.dart --dart-define=SCREENSHOTS=true
// Çıktı: build/screens/*.png ve build/screens/report.pdf
// Normal `flutter test` çalışmasında atlanır.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otosinyal_obd2/l10n/app_language.dart';
import 'package:otosinyal_obd2/main.dart';
import 'package:otosinyal_obd2/models/vehicle.dart';
import 'package:otosinyal_obd2/providers/obd_provider.dart';
import 'package:otosinyal_obd2/screens/connect_screen.dart';
import 'package:otosinyal_obd2/screens/inspection_check_screen.dart';
import 'package:otosinyal_obd2/screens/adapter_guide_screen.dart';
import 'package:otosinyal_obd2/screens/root_screen.dart';
import 'package:otosinyal_obd2/screens/settings_screen.dart';
import 'package:otosinyal_obd2/screens/smart_diagnostic_tools_screen.dart';
import 'package:otosinyal_obd2/screens/vehicle_health_score_screen.dart';
import 'package:otosinyal_obd2/services/diagnostic_report_service.dart';
import 'package:otosinyal_obd2/widget/bottom_bar/custom_bottom_bar.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const bool _enabled = bool.fromEnvironment('SCREENSHOTS');
final _rootKey = GlobalKey();
const _outDir = 'build/screens';

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  var added = false;
  for (final path in paths) {
    final file = File(path);
    if (path.startsWith('assets/')) {
      loader.addFont(rootBundle.load(path));
      added = true;
    } else if (file.existsSync()) {
      final bytes = file.readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
      added = true;
    }
  }
  if (added) await loader.load();
}

Future<void> _settle(WidgetTester tester, {int rounds = 12}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void _setView(WidgetTester tester, {double height = 852}) {
  const dpr = 3.0;
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = Size(393 * dpr, height * dpr);
  tester.view.padding = const FakeViewPadding(top: 59 * dpr, bottom: 34 * dpr);
  tester.view.viewPadding = const FakeViewPadding(top: 59 * dpr, bottom: 34 * dpr);
}

Future<void> _shot(WidgetTester tester, String name) async {
  await _settle(tester, rounds: 6);
  final boundary = _rootKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$_outDir/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(data!.buffer.asUint8List());
  });
  // ignore: avoid_print
  print('screenshot: $name');
}

Future<void> _tapNav(WidgetTester tester, String label) async {
  final target = find.descendant(of: find.byType(CustomBottomBar), matching: find.text(label));
  await tester.tap(target.first, warnIfMissed: false);
  await _settle(tester);
}

Finder get _root => find.byType(RootScreen, skipOffstage: false);

ObdProvider _obd(WidgetTester tester) => Provider.of<ObdProvider>(tester.element(_root), listen: false);

Future<void> _push(WidgetTester tester, Widget page) async {
  Navigator.of(tester.element(_root)).push(MaterialPageRoute<void>(builder: (_) => page));
  await _settle(tester);
}

Future<void> _pop(WidgetTester tester) async {
  Navigator.of(tester.element(_root)).pop();
  await _settle(tester);
}

Future<void> _runScenario(WidgetTester tester, {required String lang}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'otosinyal_privacy_consent_accepted': true,
    'otosinyal_language_mode': lang == 'en' ? 'english' : 'turkish',
  });
  final language = AppLanguage();
  await tester.runAsync(language.load);

  _setView(tester);
  await tester.pumpWidget(RepaintBoundary(key: _rootKey, child: buildAppProviders(language: language, child: const OtosinyalApp())));
  await tester.pump(const Duration(seconds: 2));
  await _settle(tester, rounds: 20);

  await _shot(tester, '${lang}_01_home_disconnected');

  final obd = _obd(tester);
  unawaited(obd.toggleDemoMode());
  await tester.pump(const Duration(seconds: 3));
  await _settle(tester, rounds: 20);
  await _shot(tester, '${lang}_02_home_demo');

  _setView(tester, height: 1900);
  await _settle(tester);
  await _shot(tester, '${lang}_03_home_demo_full');

  await _tapNav(tester, lang == 'en' ? 'Live' : 'Canlı');
  await _shot(tester, '${lang}_04_live_full');

  unawaited(obd.readTroubleCodes());
  await tester.pump(const Duration(seconds: 2));
  unawaited(obd.readFreezeFrame());
  await tester.pump(const Duration(seconds: 2));
  unawaited(obd.readReadiness());
  await tester.pump(const Duration(seconds: 1));
  await _tapNav(tester, 'DTC');
  _setView(tester, height: 2400);
  await _settle(tester);
  await _shot(tester, '${lang}_05_dtc_full');

  _setView(tester);
  await _settle(tester);
  await _shot(tester, '${lang}_06_dtc_viewport');

  await _push(tester, const InspectionCheckScreen());
  _setView(tester, height: 1900);
  final startButton = find.byIcon(Icons.fact_check_rounded);
  if (startButton.evaluate().isNotEmpty) {
    await tester.tap(startButton.first, warnIfMissed: false);
    await tester.pump(const Duration(seconds: 3));
  }
  await _settle(tester);
  await _shot(tester, '${lang}_07_inspection_full');
  _setView(tester);
  await _pop(tester);

  await _push(tester, const ConnectionScreen());
  await _shot(tester, '${lang}_08_connect');
  await _pop(tester);

  _setView(tester, height: 1500);
  await _push(tester, const AdapterGuideScreen());
  await _shot(tester, '${lang}_09_adapter_guide');
  await _pop(tester);

  await _push(tester, const VehicleHealthScoreScreen());
  await _shot(tester, '${lang}_10_health');
  await _pop(tester);

  _setView(tester, height: 2000);
  await _push(tester, const Scaffold(body: SafeArea(child: SingleChildScrollView(padding: EdgeInsets.all(16), child: SmartDiagnosticHub()))));
  await _shot(tester, '${lang}_11_tools');
  await _pop(tester);

  _setView(tester);
  showSettingsSheet(tester.element(_root));
  await _settle(tester);
  await _shot(tester, '${lang}_12_settings');
  Navigator.of(tester.element(_root)).pop();
  await _settle(tester);

  if (lang == 'tr') {
    await tester.runAsync(() async {
      final bytes = await DiagnosticReportService.buildPdfBytes(
        vehicle: const Vehicle(id: 'demo', brand: 'Volkswagen', model: 'Golf', plate: '34 ABC 123', vin: 'WVWZZZAUZHW000001'),
        obd: obd,
        data: obd.data,
      );
      File('$_outDir/report.pdf')
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(bytes);
    });
  }

  // Demo zamanlayıcılarını durdur.
  unawaited(obd.toggleDemoMode());
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  setUpAll(() async {
    if (!_enabled) return;
    await _loadFont('Inter', const [
      'assets/fonts/Inter-Regular.ttf',
      'assets/fonts/Inter-SemiBold.ttf',
      'assets/fonts/Inter-Bold.ttf',
      'assets/fonts/Inter-ExtraBold.ttf',
    ]);
    // Yazı tipi belirtmeyen metinler (iOS'ta sistem yazı tipine düşer) testte de okunur olsun.
    for (final family in const ['Roboto', 'monospace', 'Courier', '.SF Pro Text', 'CupertinoSystemText']) {
      await _loadFont(family, const ['assets/fonts/Inter-Regular.ttf', 'assets/fonts/Inter-SemiBold.ttf', 'assets/fonts/Inter-Bold.ttf', 'assets/fonts/Inter-ExtraBold.ttf']);
    }
    await _loadFont('MaterialIcons', const ['build/test_fonts/MaterialIcons-Regular.otf']);
  });

  for (final lang in const ['tr', 'en']) {
    testWidgets('screenshots $lang', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await _runScenario(tester, lang: lang);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        tester.view.reset();
      }
    }, skip: !_enabled);
  }
}
