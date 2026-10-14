import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:otosinyal_obd2/providers/ble_provider.dart';
import 'package:otosinyal_obd2/providers/bluetooth_provider.dart';
import 'package:otosinyal_obd2/providers/connection_mode_provider.dart';
import 'package:otosinyal_obd2/providers/garage_provider.dart';
import 'package:otosinyal_obd2/providers/trip_log_provider.dart';
import 'package:otosinyal_obd2/providers/units_provider.dart';
import 'package:otosinyal_obd2/providers/dtc_history_provider.dart';
import 'package:otosinyal_obd2/providers/usb_obd_provider.dart';
import 'package:otosinyal_obd2/providers/wifi_obd_provider.dart';
import 'package:otosinyal_obd2/providers/maintenance_provider.dart';
import 'package:otosinyal_obd2/providers/coding_history_provider.dart';
import 'package:otosinyal_obd2/screens/privacy_consent_screen.dart';
import 'package:otosinyal_obd2/screens/trip_log_screen.dart';
import 'package:otosinyal_obd2/screens/advanced_diagnostics_screen.dart';
import 'package:otosinyal_obd2/screens/car_screen.dart';
import 'package:otosinyal_obd2/screens/connect_screen.dart';
import 'package:otosinyal_obd2/services/data_backup_service.dart';
import 'package:otosinyal_obd2/l10n/tx.dart';
import 'package:otosinyal_obd2/l10n/app_language.dart';
import 'package:otosinyal_obd2/screens/coding_history_screen.dart';

class _DismissibleCupertinoSheetRoute<T> extends CupertinoSheetRoute<T> {
  _DismissibleCupertinoSheetRoute({
    required super.builder,
    super.enableDrag,
    Color barrierColor = const Color(0x73000000), // ~45% black
  }) : _barrierColor = barrierColor;

  final Color _barrierColor;

  @override
  Color? get barrierColor => _barrierColor;

  @override
  bool get barrierDismissible => true;

  @override
  String get barrierLabel => tx('Kapat');
}

void showSettingsSheet(BuildContext context) {
  HapticFeedback.mediumImpact();

  Navigator.of(context, rootNavigator: true).push(
    _DismissibleCupertinoSheetRoute(
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (sheetContext) {
        return NotificationListener<DraggableScrollableNotification>(
          onNotification: (notification) {
            if (notification.extent <= notification.minExtent + 0.01) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (Navigator.canPop(sheetContext)) {
                  Navigator.pop(sheetContext);
                }
              });
            }
            return false;
          },
          child: DraggableScrollableSheet(
            initialChildSize: 0.55,
            minChildSize: 0.40,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) {
              return SettingsSheet(scrollController: scrollController);
            },
          ),
        );
      },
    ),
  );
}

class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key, required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final bluetooth = context.watch<BluetoothProvider>();
    final ble = context.watch<BleProvider>();
    final mode = context.watch<ConnectionModeProvider>().mode;
    final garage = context.watch<GarageProvider>();
    final units = context.watch<UnitsProvider>();

    final isBleMode = mode == ConnectionMode.ble;
    final isConnected = isBleMode ? ble.isConnected : bluetooth.isConnected;
    final connectedName = isBleMode
        ? ble.connectedDevice?.name
        : bluetooth.connectedDevice?.name;

    final deviceLabel = isConnected
        ? '${connectedName ?? tx('Bilinmeyen Cihaz')} (${isBleMode ? 'BLE' : tx('Klasik')})'
        : tx('Bağlı değil');

    final activeVehicleLabel = garage.activeVehicle?.displayName.isNotEmpty == true
        ? garage.activeVehicle!.displayName
        : tx('Seçili araç yok');

    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surface.withOpacity(0.95),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 12, bottom: 4),
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.onSurface.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),

                  Padding(
                    padding: EdgeInsets.fromLTRB(24, 16, 24, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          tx('Ayarlar'),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colorScheme.onSurface.withOpacity(0.1),
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 12),

                  // ── Tiles ─────────────────────────────────────
                  Padding(
                    padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPadding + 40),
                    child: Column(
                      children: [
                        _SettingsTile(
                          icon: isConnected
                              ? Icons.bluetooth_connected_rounded
                              : Icons.bluetooth_disabled_rounded,
                          label: tx('Bağlı Cihaz'),
                          trailing: deviceLabel,
                          colorScheme: colorScheme,
                          onTap:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>const ConnectionScreen())),
                        ),
                        const SizedBox(height: 10),
                        _SettingsTile(
                          icon: Icons.directions_car_filled_rounded,
                          label: tx('Garajım'),
                          trailing: garage.vehicles.isEmpty ? tx('İsteğe bağlı') : tx('{0} araç • {1}', [garage.vehicles.length, activeVehicleLabel]),
                          colorScheme: colorScheme,
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CarScreen())),
                        ),
                        const SizedBox(height: 10),
                        _SettingsTile(
                          icon: Icons.monitor_heart_rounded,
                          label: tx('Canlı Teşhis'),
                          trailing: tx('VIN • ECU • Sensörler'),
                          colorScheme: colorScheme,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const AdvancedDiagnosticsScreen()),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _SettingsTile(
                          icon: Icons.route_outlined,
                          label: tx('Sürüş Geçmişi'),
                          colorScheme: colorScheme,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const TripLogScreen(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _SettingsTile(
                          icon: Icons.build_circle_outlined,
                          label: tx('Bakım Hatırlatıcıları'),
                          trailing: tx('{0} bekleyen', [context.watch<MaintenanceProvider>().dueItems.length]),
                          colorScheme: colorScheme,
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdvancedDiagnosticsScreen())),
                        ),
                        const SizedBox(height: 10),
                        _SettingsTile(
                          icon: Icons.language_rounded,
                          label: tx('Dil'),
                          trailing: _languageLabel(context.watch<AppLanguage>().mode),
                          colorScheme: colorScheme,
                          onTap: () => _chooseLanguage(context),
                        ),
                        const SizedBox(height: 10),
                        _SettingsTile(
                          icon: Icons.straighten_rounded,
                          label: tx('Birimler'),
                          colorScheme: colorScheme,
                          trailing: units.isMetric ? 'km/h, °C' : 'mph, °F',
                          onTap: () => units.toggle(),
                        ),
                        const SizedBox(height: 10),
                        _SettingsTile(
                          icon: Icons.restore_rounded,
                          label: tx('Kodlama Yedekleri'),
                          trailing: '${context.watch<CodingHistoryProvider>().records.length}',
                          colorScheme: colorScheme,
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CodingHistoryScreen())),
                        ),
                        const SizedBox(height: 10),
                        _SettingsTile(
                          icon: Icons.file_upload_outlined,
                          label: tx('Verileri Dışa Aktar'),
                          trailing: tx('.otosinyal şifreli'),
                          colorScheme: colorScheme,
                          onTap: () => _exportData(context),
                        ),
                        const SizedBox(height: 10),
                        _SettingsTile(
                          icon: Icons.file_download_outlined,
                          label: tx('Verileri İçe Aktar'),
                          trailing: tx('.otosinyal yükle'),
                          colorScheme: colorScheme,
                          onTap: () => _importData(context),
                        ),
                        const SizedBox(height: 10),
                        _SettingsTile(
                          icon: Icons.delete_sweep_outlined,
                          label: tx('Garajı Temizle'),
                          colorScheme: colorScheme,
                          onTap: garage.vehicles.isEmpty
                              ? null
                              : () => _confirmClearGarage(context, garage),
                        ),
                        const SizedBox(height: 10),
                        _SettingsTile(
                          icon: Icons.shield_outlined,
                          label: tx('Gizlilik Politikası'),
                          colorScheme: colorScheme,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const PrivacyPolicyReadOnlyScreen(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _SettingsTile(
                          icon: Icons.info_outline_rounded,
                          label: tx('Hakkında'),
                          colorScheme: colorScheme,
                          onTap: () => _showAboutDialog(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _exportData(BuildContext context) async {
    try {
      await DataBackupService.shareBackup(
        garage: context.read<GarageProvider>(),
        trips: context.read<TripLogProvider>(),
        dtcHistory: context.read<DtcHistoryProvider>(),
        units: context.read<UnitsProvider>(),
        connectionMode: context.read<ConnectionModeProvider>(),
        wifi: context.read<WifiObdProvider>(),
        usb: context.read<UsbObdProvider>(),
        maintenance: context.read<MaintenanceProvider>(),
        codingHistory: context.read<CodingHistoryProvider>(),
      );
    } catch (error) {
      if (context.mounted) {
        final rootNavigator = Navigator.of(context, rootNavigator: true);
        final rootContext = rootNavigator.context;
        if (rootNavigator.canPop()) {
          rootNavigator.pop();
          await Future<void>.delayed(const Duration(milliseconds: 220));
        }
        await _showBackupErrorDialog(
          rootContext,
          title: tx('Yedek dışa aktarılamadı'),
          error: error,
        );
      }
    }
  }

  Future<void> _importData(BuildContext context) async {
    try {
      final backup = await DataBackupService.pickBackup();
      if (backup == null || !context.mounted) return;
      final approved = await showDialog<bool>(
        context: context,
        useRootNavigator: true,
        builder: (dialogContext) => AlertDialog(
          title: Text(tx('Yedeği geri yükle?')),
          content: Text(tx('Garaj, sürüş geçmişi, DTC geçmişi, kodlama geri dönüş kayıtları ve ayarlar seçilen şifreli .otosinyal yedeğiyle değiştirilecek.')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(tx('Vazgeç'))),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(tx('GERİ YÜKLE'))),
          ],
        ),
      );
      if (approved != true || !context.mounted) return;
      final rootNavigator = Navigator.of(context, rootNavigator: true);
      final rootContext = rootNavigator.context;
      await DataBackupService.restoreBackup(
        backup: backup,
        garage: context.read<GarageProvider>(),
        trips: context.read<TripLogProvider>(),
        dtcHistory: context.read<DtcHistoryProvider>(),
        units: context.read<UnitsProvider>(),
        connectionMode: context.read<ConnectionModeProvider>(),
        wifi: context.read<WifiObdProvider>(),
        usb: context.read<UsbObdProvider>(),
        maintenance: context.read<MaintenanceProvider>(),
        codingHistory: context.read<CodingHistoryProvider>(),
      );
      // Ayar sheet'i root dialog'un üstünde kalmasın; sonucu her zaman en üst
      // navigator katmanında göster.
      if (rootNavigator.canPop()) {
        rootNavigator.pop();
        await Future<void>.delayed(const Duration(milliseconds: 220));
      }
      await _showBackupSuccessDialog(rootContext);
    } catch (error) {
      if (context.mounted) {
        final rootNavigator = Navigator.of(context, rootNavigator: true);
        final rootContext = rootNavigator.context;
        if (rootNavigator.canPop()) {
          rootNavigator.pop();
          await Future<void>.delayed(const Duration(milliseconds: 220));
        }
        await _showBackupErrorDialog(
          rootContext,
          title: tx('Yedek içe aktarılamadı'),
          error: error,
        );
      }
    }
  }

  Future<void> _showBackupErrorDialog(
    BuildContext context, {
    required String title,
    required Object error,
  }) async {
    final message = error
        .toString()
        .replaceFirst('FormatException: ', '')
        .replaceFirst('Exception: ', '');
    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF171011),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.redAccent.withOpacity(.42)),
        ),
        icon: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.redAccent.withOpacity(.12),
            border: Border.all(color: Colors.redAccent.withOpacity(.35)),
          ),
          child: const Icon(Icons.lock_outline_rounded, color: Colors.redAccent, size: 29),
        ),
        title: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, height: 1.45, fontSize: 13),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(tx('KAPAT'), style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showBackupSuccessDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF101611),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.greenAccent.withOpacity(.35)),
        ),
        icon: const Icon(Icons.verified_rounded, color: Colors.greenAccent, size: 48),
        title: Text(
          tx('Yedek geri yüklendi'),
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: Text(
          tx('OTOSİNYAL verileri başarıyla doğrulandı ve uygulamaya aktarıldı.'),
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, height: 1.45),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(tx('TAMAM'), style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmClearGarage(BuildContext context, GarageProvider garage) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF151011),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          tx('Garajı temizle?'),
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          tx('Kayıtlı tüm araçlar silinecek. Bu işlem geri alınamaz.'),
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(tx('Vazgeç'), style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              for (final v in List.of(garage.vehicles)) {
                garage.removeVehicle(v.id);
              }
              Navigator.of(dialogContext).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(tx('Temizle'), style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static String _languageLabel(AppLanguageMode mode) => switch (mode) {
        AppLanguageMode.system => tx('Otomatik'),
        AppLanguageMode.turkish => 'Türkçe',
        AppLanguageMode.english => 'English',
      };

  Future<void> _chooseLanguage(BuildContext context) async {
    final language = context.read<AppLanguage>();
    final selected = await showDialog<AppLanguageMode>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        backgroundColor: const Color(0xFF151011),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(tx('Uygulama dili'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        children: [
          for (final mode in AppLanguageMode.values)
            RadioListTile<AppLanguageMode>(
              value: mode,
              groupValue: language.mode,
              onChanged: (value) => Navigator.pop(dialogContext, value),
              title: Text(_languageLabel(mode), style: const TextStyle(color: Colors.white)),
              subtitle: mode == AppLanguageMode.system
                  ? Text(tx('Telefon dili Türkçe ise Türkçe, değilse İngilizce'), style: const TextStyle(color: Colors.white54, fontSize: 12))
                  : null,
            ),
        ],
      ),
    );
    if (selected == null || selected == language.mode) return;
    await language.setMode(selected);
  }

  void _showAboutDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF151011),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          tx('OTOSİNYAL OBD2'),
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Text(
            tx('Sürüm 1.0.0 • Build 14\n\nBU SÜRÜMDE NELER DEĞİŞTİ?\n\n• iOS ELM327 bağlantı akışı iyileştirildi.\n• VIN okumasının bağlantıyı ve canlı veriyi bekletmemesi sağlandı.\n• ECU doğrulama ve canlı veri başlangıcı daha erken aşamaya alındı.\n• Adaptör özellikleri ve seçilen protokol için profil bilgileri geliştirildi.\n• Desteklenmeyen komutlar ve NO DATA yanıtları daha kontrollü ele alınıyor.\n• BUFFER FULL, zaman aşımı ve yeniden bağlantı akışları iyileştirildi.\n• DTC/PDF teşhis raporu ve hata açıklamaları geliştirildi.\n• iOS bağlantı kararlılığına yönelik altyapı düzenlemeleri yapıldı.\n\nOTOSİNYAL; gerçek zamanlı ECU verileri, arıza teşhisi, araç profilleri ve gelişmiş analiz araçlarını tek bir otomotiv platformunda birleştirir.\n\nTEŞHİS SENDE • KONTROL SENDE'),
            style: TextStyle(color: Colors.white70, height: 1.45),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(tx('Tamam'), style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? trailing;
  final ColorScheme colorScheme;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.colorScheme,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null && trailing == null;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: colorScheme.primary),
                ),
                SizedBox(width: 14),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface.withOpacity(0.85),
                  ),
                ),
                Spacer(),
                if (trailing != null)
                  Flexible(
                    child: Text(
                      trailing!,
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface.withOpacity(0.4),
                      ),
                    ),
                  ),
                if (onTap != null) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: colorScheme.onSurface.withOpacity(
                      isDisabled ? 0.1 : 0.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
