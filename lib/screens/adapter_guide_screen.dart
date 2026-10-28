import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:otosinyal_obd2/core/app_colors.dart';
import 'package:otosinyal_obd2/l10n/tx.dart';
import 'package:otosinyal_obd2/widget/common/oto_ui.dart';

/// "Hangi adaptör çalışır?" rehberi.
///
/// iPhone yalnız Bluetooth LE (BLE) ve Wi‑Fi ELM327 adaptörlerle konuşabilir;
/// piyasadaki ucuz "Bluetooth v1.5 / v2.1" adaptörlerin çoğu Classic (SPP)
/// olduğu için iPhone'da hiç görünmez. Bu ekran kullanıcıya bunu baştan anlatır.
class AdapterGuideScreen extends StatelessWidget {
  const AdapterGuideScreen({super.key});

  bool get _isIos => defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: Colors.white,
        title: Text(tx('Hangi adaptör çalışır?'), style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _Intro(isIos: _isIos),
          const SizedBox(height: 14),
          _GuideSection(
            icon: Icons.bluetooth_rounded,
            color: AppColors.success,
            title: tx('Bluetooth LE (BLE) adaptörler'),
            badge: tx('Önerilen'),
            lines: [
              tx('iPhone ve Android ile çalışır.'),
              tx('Kutusunda genelde "Bluetooth 4.0", "BLE" veya "iOS uyumlu" yazar.'),
              tx('Telefonun Bluetooth ayarlarında eşleştirme yapılmaz; cihaz doğrudan uygulamanın içinden seçilir.'),
              tx('Örnekler: Vgate iCar Pro BLE, Veepeak OBDCheck BLE, OBDLink CX.'),
            ],
          ),
          _GuideSection(
            icon: Icons.wifi_rounded,
            color: AppColors.info,
            title: tx('Wi‑Fi adaptörler'),
            badge: tx('Çalışır'),
            lines: [
              tx('iPhone ve Android ile çalışır.'),
              tx('Telefonu adaptörün yayınladığı Wi‑Fi ağına bağla (ör. "WiFi_OBDII").'),
              tx('Varsayılan adres çoğunlukla 192.168.0.10, port 35000 olur.'),
              tx('Bağlıyken telefonda internet olmayabilir; bu normaldir.'),
            ],
          ),
          _GuideSection(
            icon: Icons.bluetooth_disabled_rounded,
            color: AppColors.danger,
            title: tx('Bluetooth Classic (SPP) adaptörler'),
            badge: _isIos ? tx('iPhone\'da çalışmaz') : tx('Android\'de çalışır'),
            lines: [
              tx('Telefonun Bluetooth ayarlarında 1234 veya 0000 PIN koduyla eşleşen adaptörler bu türdendir.'),
              tx('Apple, iPhone\'da bu tür seri Bluetooth bağlantısına izin vermez; adaptör listede hiç görünmez.'),
              tx('Ucuz "ELM327 Bluetooth v1.5 / v2.1" adaptörlerin çoğu bu gruptadır.'),
            ],
          ),
          _GuideSection(
            icon: Icons.usb_rounded,
            color: AppColors.warning,
            title: tx('USB kablolu adaptörler'),
            badge: _isIos ? tx('iPhone\'da çalışmaz') : tx('Android\'de çalışır'),
            lines: [
              tx('Android\'de OTG dönüştürücü ile kullanılabilir.'),
              tx('iPhone USB üzerinden ELM327 seri bağlantısını desteklemez.'),
            ],
          ),
          const SizedBox(height: 4),
          OtoCard(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_outline_rounded, color: AppColors.accentBright, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tx('Kodlama ve adaptasyon için adaptörün uzun mesaj (ISO-TP) desteği gerekir. Çok ucuz klon adaptörler arıza kodu okuyabilir ama kodlamayı taşıyamayabilir; bu durumda Kodlama sekmesi görünmez.'),
                  style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.45),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.isIos});
  final bool isIos;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF2A0D10), Color(0xFF101113)]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.accentBorder),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.cable_rounded, color: AppColors.accentBright, size: 30),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tx('Adaptör seçimi'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(
              isIos
                  ? tx('iPhone yalnızca Bluetooth LE (BLE) ve Wi‑Fi OBD adaptörleriyle çalışır. Adaptörün listede görünmüyorsa büyük ihtimalle Bluetooth Classic bir modeldir.')
                  : tx('Android; Bluetooth LE, Bluetooth Classic, Wi‑Fi ve USB OBD adaptörleriyle çalışır.'),
              style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.45),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _GuideSection extends StatelessWidget {
  const _GuideSection({required this.icon, required this.color, required this.title, required this.badge, required this.lines});
  final IconData icon;
  final Color color;
  final String title;
  final String badge;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: OtoCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800))),
            OtoStatusBadge(label: badge, color: color),
          ]),
          const SizedBox(height: 10),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(width: 5, height: 5, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                ),
                const SizedBox(width: 9),
                Expanded(child: Text(line, style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4))),
              ]),
            ),
        ]),
      ),
    );
  }
}
