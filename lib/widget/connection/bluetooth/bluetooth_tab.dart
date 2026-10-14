import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:otosinyal_obd2/models/bluetooth_enums.dart';
import 'package:otosinyal_obd2/models/obd_device.dart';
import 'package:otosinyal_obd2/core/app_colors.dart';
import 'package:otosinyal_obd2/providers/ble_provider.dart';
import 'package:otosinyal_obd2/providers/bluetooth_provider.dart';
import 'package:otosinyal_obd2/providers/connection_mode_provider.dart';
import 'package:otosinyal_obd2/providers/scannable_provider.dart';
import 'package:otosinyal_obd2/services/auto_connect_service.dart';

/// Aktif bağlantı moduna (Classic/BLE) göre doğru provider'ı döner.
ScannableBluetoothProvider activeProvider(BuildContext context) {
  final mode = context.read<ConnectionModeProvider>().mode;
  return mode == ConnectionMode.ble
      ? context.read<BleProvider>()
      : context.read<BluetoothProvider>();
}

class BluetoothTab extends StatefulWidget {
  const BluetoothTab({super.key});

  @override
  State<BluetoothTab> createState() => _BluetoothTabState();
}

class _BluetoothTabState extends State<BluetoothTab> {
  Timer? _autoConnectTimer;
  bool _autoConnectDone = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final provider = activeProvider(context);

      if (!provider.isScanning && !provider.isConnected) {
        Future.delayed(const Duration(milliseconds: 50), () {
          if (!mounted) return;
          _handleScan(context);
        });
      }
    });
  }

  @override
  void dispose() {
    _autoConnectTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleScan(BuildContext context) async {
    final result = await activeProvider(context).startScan();
    if (!mounted) return;

    if (result == BluetoothScanResult.permanentlyDenied) {
      _showPermissionDialog(context);
      return;
    }

    if (result == BluetoothScanResult.started) {
      _tryAutoConnectSoon(context);
    }
  }

  /// Tarama sırasında bulunan cihazlar arasında en son bağlanılan cihaz
  /// varsa, kullanıcı hiçbir şeye dokunmadan otomatik olarak bağlanır.
  void _tryAutoConnectSoon(BuildContext context) {
    if (_autoConnectDone) return;
    _autoConnectTimer?.cancel();

    _autoConnectTimer = Timer.periodic(const Duration(milliseconds: 700), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final provider = activeProvider(context);
      if (provider.isConnected || provider.isConnecting) {
        timer.cancel();
        return;
      }

      final last = await AutoConnectService.getLastDevice();
      if (last == null) {
        timer.cancel();
        return;
      }

      final matches = provider.discoveredDevices.where(
        (d) => d.address == last.address && d.isBle == last.isBle,
      );

      if (matches.isNotEmpty) {
        timer.cancel();
        _autoConnectDone = true;
        if (!mounted) return;
        _connectToAdapter(context, provider, matches.first);
      } else if (!provider.isScanning) {
        timer.cancel();
      }
    });
  }

  void _showPermissionDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Bluetooth erişimi gerekli',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Bluetooth izni kalıcı olarak reddedildi. '
          'Lütfen uygulama ayarlarından etkinleştirin.',
          style: TextStyle(color: Colors.white54),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'İptal',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            child: const Text(
              'Ayarları Aç',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mode = context.watch<ConnectionModeProvider>().mode;
    final classic = context.watch<BluetoothProvider>();
    final ble = context.watch<BleProvider>();
    final ScannableBluetoothProvider active =
        mode == ConnectionMode.ble ? ble : classic;

    return Column(
      children: [
        if (!active.isConnected) ...[
          const _ObdInstallationGuide(),
          const SizedBox(height: 12),
        ],
        BluetoothScanStatusCard(onRefresh: () => _handleScan(context)),
        const SizedBox(height: 20),
        Expanded(child: BluetoothDevicePanel(onScan: () => _handleScan(context))),
      ],
    );
  }
}

/// Tarama durumu kartı. Hem Classic hem BLE provider'ını dinler,
/// aktif olan hangisiyse onun verisini gösterir.
class BluetoothScanStatusCard extends StatelessWidget {
  final VoidCallback onRefresh;
  const BluetoothScanStatusCard({super.key, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final mode = context.watch<ConnectionModeProvider>().mode;
    final classic = context.watch<BluetoothProvider>();
    final ble = context.watch<BleProvider>();
    final ScannableBluetoothProvider active =
        mode == ConnectionMode.ble ? ble : classic;

    final isScanning = active.isScanning;
    final devicesCount = active.discoveredDevices.length;

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: isScanning
              ? null
              : () => Future.delayed(
                  const Duration(milliseconds: 150),
                  onRefresh,
                ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: isScanning
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.accentBright,
                          ),
                        )
                      : const Icon(Icons.bluetooth, color: AppColors.accentBright),
                ),
                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isScanning ? "Taranıyor..." : "Tarama tamamlandı",
                        textScaler: TextScaler.noScaling,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isScanning
                            ? "Cihazınız aranıyor..."
                            : "$devicesCount cihaz bulundu",
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                if (!isScanning)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.refresh,
                      color: AppColors.accentBright,
                      size: 20,
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

/// Cihaz listesini ve mod seçiciyi barındıran ana panel.
class BluetoothDevicePanel extends StatelessWidget {
  final VoidCallback onScan;
  const BluetoothDevicePanel({super.key, required this.onScan});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const BluetoothModeSwitcher(),
          Expanded(child: BluetoothDeviceList(onScan: onScan)),
        ],
      ),
    );
  }
}

/// Classic / BLE seçici — artık gerçekten mod değiştiriyor.
/// Mod değiştiğinde ilgili provider'da otomatik tarama başlatılır.
class BluetoothModeSwitcher extends StatelessWidget {
  const BluetoothModeSwitcher({super.key});

  void _selectMode(BuildContext context, ConnectionMode mode) {
    final modeProvider = context.read<ConnectionModeProvider>();
    if (modeProvider.mode == mode) return;

    // Aynı anda Classic ve BLE oturumu açık kalmasın. Özellikle bazı ELM
    // klonlarında iki transport'un eşzamanlı açık kalması veri kanalını kilitler.
    if (mode == ConnectionMode.ble) {
      unawaited(context.read<BluetoothProvider>().disconnect());
    } else {
      unawaited(context.read<BleProvider>().disconnect());
    }

    modeProvider.setMode(mode);

    Future.delayed(const Duration(milliseconds: 120), () {
      if (!context.mounted) return;
      final ScannableBluetoothProvider provider = mode == ConnectionMode.ble
          ? context.read<BleProvider>()
          : context.read<BluetoothProvider>();
      if (!provider.isScanning && !provider.isConnected) {
        provider.startScan();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // iOS, ELM327 Bluetooth Classic (SPP) bağlantısını desteklemez; yalnız BLE.
    if (defaultTargetPlatform == TargetPlatform.iOS) return const SizedBox.shrink();
    final mode = context.watch<ConnectionModeProvider>().mode;
    final isClassic = mode == ConnectionMode.classic;

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _selectMode(context, ConnectionMode.classic),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: isClassic ? AppColors.accent : Colors.transparent,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                "Classic / SPP",
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  color: isClassic ? Colors.black : Colors.white54,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () => _selectMode(context, ConnectionMode.ble),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: !isClassic ? AppColors.accent : Colors.transparent,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(24),
                ),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "BLE 4.0+",
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      color: !isClassic ? Colors.black : Colors.white54,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "ÖNERİLEN",
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      color: !isClassic ? Colors.black54 : Colors.white30,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Cihaz listesi. Aktif moda göre Classic ya da BLE provider'ını dinler.
class BluetoothDeviceList extends StatelessWidget {
  final VoidCallback onScan;
  const BluetoothDeviceList({super.key, required this.onScan});

  @override
  Widget build(BuildContext context) {
    final mode = context.watch<ConnectionModeProvider>().mode;
    final classic = context.watch<BluetoothProvider>();
    final ble = context.watch<BleProvider>();
    final ScannableBluetoothProvider active =
        mode == ConnectionMode.ble ? ble : classic;

    final isScanning = active.isScanning;
    final devices = active.discoveredDevices;

    if (devices.isEmpty && !isScanning) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 80,
              color: AppColors.accent.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 10),
            const Text(
              "Cihaz bulunamadı",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              mode == ConnectionMode.ble
                  ? "BLE cihazınızın açık ve\nyakında olduğundan emin olun"
                  : "Tarayıcının takılı olduğundan ve kontağın\naçık olduğundan emin olun",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 200,
              height: 50,
              child: ElevatedButton(
                onPressed: onScan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text(
                  "Taramayı Başlat",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: devices.length,
      separatorBuilder: (context, index) {
        return Divider(color: Colors.white.withAlpha(10), height: 1);
      },
      itemBuilder: (context, index) {
        final device = devices[index];
        return BluetoothDeviceTile(
          key: ValueKey('${mode.name}-${device.address}'),
          device: device,
        );
      },
    );
  }
}

class BluetoothDeviceTile extends StatelessWidget {
  final ObdDevice device;

  const BluetoothDeviceTile({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    final mode = context.watch<ConnectionModeProvider>().mode;
    final classic = context.watch<BluetoothProvider>();
    final ble = context.watch<BleProvider>();
    final ScannableBluetoothProvider active =
        mode == ConnectionMode.ble ? ble : classic;

    final isConnected = active.connectedDevice?.address == device.address;
    final isPaired = !isConnected;

    return ListTile(
      onTap: isConnected
          ? null
          : () => _connectToAdapter(context, active, device),
      leading: Icon(
        device.isBle ? Icons.bluetooth_audio_rounded : Icons.bluetooth,
        color: isConnected ? AppColors.accentBright : Colors.white54,
      ),
      title: Text(
        device.name,
        textScaler: TextScaler.noScaling,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        device.isBle && device.rssi != null
            ? '${device.address}  •  ${device.rssi} dBm'
            : '${device.address}  •  Sinyal ölçümü yok',
        textScaler: TextScaler.noScaling,
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (device.isBle && device.rssi != null) ...[
            _RssiIndicator(rssi: device.rssi!),
            const SizedBox(width: 10),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isConnected ? AppColors.accentSoft : Colors.white10,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isConnected ? "Bağlı" : (isPaired ? "Eşleşti" : "Uygun"),
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                color: isConnected ? AppColors.accentBright : Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isConnected ? AppColors.accentBright : Colors.white24,
                width: 2,
              ),
              color: isConnected ? AppColors.accentBright : Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }
}

class _RssiIndicator extends StatelessWidget {
  const _RssiIndicator({required this.rssi});
  final int rssi;

  @override
  Widget build(BuildContext context) {
    final strength = ((rssi + 100) / 60).clamp(0.0, 1.0);
    final color = strength > .65 ? AppColors.success : strength > .35 ? Colors.orange : AppColors.accent;
    return SizedBox(
      width: 28,
      height: 22,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(4, (i) => Container(
          width: 4,
          height: 6.0 + i * 4,
          decoration: BoxDecoration(
            color: strength >= (i + 1) / 4 ? color : Colors.white12,
            borderRadius: BorderRadius.circular(3),
          ),
        )),
      ),
    );
  }
}

/// Herhangi bir Bluetooth adaptörüne (Classic veya BLE) bağlanma mantığı.
/// [provider] parametresi runtime'da her zaman bir [ChangeNotifier]
/// (BluetoothProvider ya da BleProvider) olduğu için Listenable olarak
/// kullanılabilir.
Future<void> _connectToAdapter(
  BuildContext context,
  ScannableBluetoothProvider provider,
  ObdDevice device,
) async {
  bool isCanceled = false;
  final listenable = provider as Listenable;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return PopScope(
        canPop: false,
        child: AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 60),
          backgroundColor: AppColors.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          contentPadding: EdgeInsets.zero,
          content: SizedBox(
            height: 220,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(
                    width: 55,
                    height: 55,
                    child: CircularProgressIndicator(
                      strokeWidth: 4.5,
                      color: AppColors.accentBright,
                    ),
                  ),

                  AnimatedBuilder(
                    animation: listenable,
                    builder: (context, child) {
                      return Text(
                        provider.connectionMessage,
                        textAlign: TextAlign.center,
                        textScaler: TextScaler.noScaling,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),

                  Padding(
                    padding: const EdgeInsets.only(
                      left: 26,
                      right: 26,
                      bottom: 8,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: ElevatedButton(
                        onPressed: () {
                          isCanceled = true;
                          provider.cancelConnection();

                          if (Navigator.of(dialogContext).canPop()) {
                            Navigator.of(dialogContext).pop();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                        child: const Text(
                          "İptal",
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  final success = await provider.connectToDevice(device);

  if (isCanceled || !context.mounted) return;

  if (Navigator.of(context).canPop()) {
    Navigator.of(context).pop();
  }

  if (!success && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Hata: '${device.name}' yanıt vermiyor"),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }
}


class _ObdInstallationGuide extends StatelessWidget {
  const _ObdInstallationGuide();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF3A2022)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 112,
            height: 112,
            child: Lottie.asset(
              'assets/animations/obd_installation.json',
              repeat: true,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'OBD2 cihazını hazırla',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  '1. Adaptörü aracın OBD portuna tak\n'
                  '2. Kontağı aç\n'
                  '3. Aşağıdan cihazını seç ve bağlan',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 11.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
