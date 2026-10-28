// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:otosinyal_obd2/services/ble_obd_connection.dart';
import 'package:otosinyal_obd2/services/bluetooth_obd_connection.dart';
import 'package:otosinyal_obd2/services/usb_obd_connection.dart';
import 'package:otosinyal_obd2/services/wifi_obd_connection.dart';
import 'providers/ble_provider.dart';
import 'providers/connection_mode_provider.dart';
import 'providers/obd_provider.dart';
import 'providers/bluetooth_provider.dart';
import 'providers/garage_provider.dart';
import 'providers/trip_log_provider.dart';
import 'providers/units_provider.dart';
import 'providers/dtc_history_provider.dart';
import 'providers/usb_obd_provider.dart';
import 'providers/wifi_obd_provider.dart';
import 'providers/maintenance_provider.dart';
import 'providers/coding_history_provider.dart';
import 'core/app_themes.dart';
import 'core/comfort_text_scaler.dart';
import 'screens/startup_gate.dart';
import 'services/dtc_dictionary.dart';
import 'services/mode06_catalog.dart';
import 'widget/reconnection_banner.dart';
import 'package:otosinyal_obd2/l10n/tx.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_language.dart';

/// Uygulamanın tüm provider ağacı. main() ve ekran görüntüsü testleri kullanır.
Widget buildAppProviders({required AppLanguage language, required Widget child}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AppLanguage>.value(value: language),
      ChangeNotifierProvider(create: (_) => BluetoothProvider()),
      ChangeNotifierProvider(create: (_) => BleProvider()),
      ChangeNotifierProvider(create: (_) => ConnectionModeProvider()),
      ChangeNotifierProvider(create: (_) => WifiObdProvider()),
      ChangeNotifierProvider(create: (_) => UsbObdProvider()),
      ChangeNotifierProvider(create: (_) => GarageProvider()),
      ChangeNotifierProvider(create: (_) => TripLogProvider()),
      ChangeNotifierProvider(create: (_) => UnitsProvider()),
      ChangeNotifierProvider(create: (_) => DtcHistoryProvider()),
      ChangeNotifierProvider(create: (_) => MaintenanceProvider()),
      ChangeNotifierProvider(create: (_) => CodingHistoryProvider()),

      ChangeNotifierProxyProvider5<BluetoothProvider, BleProvider,
          WifiObdProvider, UsbObdProvider, ConnectionModeProvider, ObdProvider>(
        create: (context) {
          final op = ObdProvider(
            BluetoothObdConnection(context.read<BluetoothProvider>()),
          );
          // Trip log — ObdProvider'ın Garaj/TripLog provider'larına
          // doğrudan bağımlı olmasını istemediğimiz için enjekte ediyoruz.
          op.getActiveVehicleId =
              () => context.read<GarageProvider>().activeVehicle?.id;
          op.hasActiveVehicle =
              () => context.read<GarageProvider>().activeVehicle != null;
          op.onVehicleDetected = (vin, brand) => context
              .read<GarageProvider>()
              .upsertDetectedVehicle(vin: vin, brand: brand);
          op.onTripEnd =
              (trip) => context.read<TripLogProvider>().addTrip(trip);
          op.onDtcScan =
              (scan) => context.read<DtcHistoryProvider>().add(scan);
          return op;
        },
        update: (_, blueProvider, bleProvider, wifiProvider, usbProvider, modeProvider, currentObdProvider) {
          final activeConnection = switch (modeProvider.mode) {
            ConnectionMode.ble => BleObdConnection(bleProvider),
            ConnectionMode.wifi => WifiObdConnection(wifiProvider),
            ConnectionMode.usb => UsbObdConnection(usbProvider),
            ConnectionMode.classic => BluetoothObdConnection(blueProvider),
          };

          currentObdProvider!.updateConnection(activeConnection);

          return currentObdProvider;
        },
      ),
    ],
    child: child,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Arayüz dikey (portrait) için tasarlandı; yatay modda ekranlar sıkışıyor.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Dil tercihi ilk kareden önce okunur: telefon Türkçe ise Türkçe,
  // diğer tüm dillerde İngilizce (Ayarlar'dan elle değiştirilebilir).
  final language = AppLanguage();
  await language.load();
  // Dil değişince DTC sözlüğü de yeni dille yeniden yüklenir.
  language.addListener(() => unawaited(DtcDictionary.initialize()));

  // Arıza kodu sözlüğünü arka planda yükle; başlangıç akışını bloklama.
  unawaited(DtcDictionary.initialize());
  unawaited(Mode06Catalog.initialize());

  runApp(buildAppProviders(language: language, child: const OtosinyalApp()));
}

class OtosinyalApp extends StatelessWidget {
  const OtosinyalApp({super.key});

  @override
  Widget build(BuildContext context) {
    final language = context.watch<AppLanguage>();
    return MaterialApp(
      // Dil değişince tüm ekranlar yeni dille yeniden kurulur.
      key: ValueKey<bool>(AppLanguage.isEnglish),
      title: tx('OTOSİNYAL OBD2'),
      debugShowCheckedModeBanner: false,
      theme: AppThemes.darkTheme,
      locale: language.locale,
      supportedLocales: const [Locale('en'), Locale('tr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const StartupGate(),

      /// ELM adaptörü bağlantısı koptuğunda yeniden bağlanma durumunu uygulama üstünde göster.
      builder: (context, child) {
        // Küçük yazılar okunur boyuta yaklaştırılır (göz yorgunluğu).
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(textScaler: ComfortTextScaler(media.textScaler)),
          child: Stack(
          children: [
            child!,

            Consumer4<BluetoothProvider, BleProvider, ConnectionModeProvider,
                ObdProvider>(
              builder: (context, blueProvider, bleProvider, modeProvider, obdProvider, _) {
                final isBleMode = modeProvider.mode == ConnectionMode.ble;
                final isBlueReconnecting = isBleMode
                    ? bleProvider.isReconnectingBackground
                    : blueProvider.isReconnectingBackground;

                final isObdRecovering =
                    obdProvider.isRealMode &&
                    obdProvider.state == ObdConnectionState.initializing;

                final showBanner = isBlueReconnecting || isObdRecovering;

                String message = "";
                if (isBlueReconnecting) {
                  message = isBleMode
                      ? bleProvider.backgroundMessage
                      : blueProvider.backgroundMessage;
                } else if (isObdRecovering) {
                  message = obdProvider.initMessage;
                }

                return AnimatedPositioned(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  top: showBanner
                      ? MediaQuery.of(context).padding.top + 10
                      : -100,
                  left: 16,
                  right: 16,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: showBanner ? 1.0 : 0.0,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ReconnectionBanner(message: message),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        );
      },
    );
  }
}
