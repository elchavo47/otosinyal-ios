import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:otosinyal_obd2/core/app_colors.dart';
import 'package:otosinyal_obd2/screens/root_screen.dart';
import 'package:otosinyal_obd2/services/privacy_consent_service.dart';
import 'package:otosinyal_obd2/l10n/tx.dart';

/// İlk açılışta bir kez gösterilen gizlilik ve izin bilgilendirmesi.
class PrivacyConsentScreen extends StatefulWidget {
  const PrivacyConsentScreen({super.key});

  @override
  State<PrivacyConsentScreen> createState() => _PrivacyConsentScreenState();
}

class _PrivacyConsentScreenState extends State<PrivacyConsentScreen> {
  // Uygulama kişisel veri toplamadığı için bu ekran bilgilendirme amaçlıdır;
  // kullanımı engelleyen bir red/onay kilidi yoktur (App Review 5.1.1).
  Future<void> _continue() async {
    await PrivacyConsentService.setAccepted(true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const RootScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, color: AppColors.accent, size: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tx('Gizlilik ve İzinler'),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: _PolicyContent(),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _continue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    tx('Devam Et'),
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PolicyContent extends StatelessWidget {
  const _PolicyContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PolicyIntro(),
        const SizedBox(height: 20),
        _PolicySection(
          icon: Icons.bluetooth_rounded,
          title: tx('Bluetooth İzni'),
          body: tx('OTOSİNYAL OBD2, aracınızdaki ELM327 OBD2 cihazına bağlanmak ve gerçek zamanlı motor verisi (hız, RPM, sıcaklık, arıza kodları vb.) okumak için Bluetooth iznine ihtiyaç duyar. Bu izin olmadan uygulamanın temel işlevi (araç verisi okuma) çalışmaz.'),
        ),
        if (Platform.isAndroid)
          _PolicySection(
            icon: Icons.location_on_outlined,
            title: tx('Konum İzni'),
            body: tx('Android işletim sistemi, Bluetooth cihaz taraması yapabilmek için konum iznini zorunlu kılar. OTOSİNYAL OBD2 konum bilginizi kaydetmez, sunucuya göndermez veya başka bir amaçla kullanmaz — bu izin yalnızca Bluetooth taramasının teknik bir gereksinimidir.'),
          ),
        _PolicySection(
          icon: Icons.storage_rounded,
          title: tx('Cihazda Saklanan Veriler'),
          body: tx('Garajınıza eklediğiniz araç bilgileri (marka, model, plaka, yıl, yakıt tipi) yalnızca telefonunuzda, cihaz içi depolamada tutulur. Bu veriler hiçbir sunucuya gönderilmez, hiçbir üçüncü tarafla paylaşılmaz.'),
        ),
        _PolicySection(
          icon: Icons.wifi_off_rounded,
          title: tx('İnternet Kullanımı'),
          body: tx('Uygulama, araç verisi okuma ve arıza kodu görüntüleme işlevleri için internet bağlantısına ihtiyaç duymaz. Tüm işlemler cihazınızda ve doğrudan Bluetooth üzerinden aracınızla gerçekleşir.'),
        ),
        _PolicySection(
          icon: Icons.groups_outlined,
          title: tx('Üçüncü Taraflarla Paylaşım'),
          body: tx('Verileriniz reklam, analiz veya pazarlama amacıyla hiçbir üçüncü tarafla paylaşılmaz veya satılmaz. Ayrıntılı teşhis logu ya da PDF raporu paylaş düğmesine bastığınızda Android/iOS sistem paylaşım ekranı açılır; VIN, ECU cevabı ve araç verileri seçtiğiniz uygulamaya gidebilir.'),
        ),
        _PolicySection(
          icon: Icons.wifi_rounded,
          title: tx('Wi‑Fi / USB İletişimi'),
          body: tx('Wi‑Fi OBD bağlantısı yalnızca girdiğiniz IP ve TCP portuna, USB OTG bağlantısı ise seçtiğiniz kabloya komut gönderir. OTOSİNYAL bu verileri otomatik olarak bir sunucuya yüklemez.'),
        ),
        _PolicySection(
          icon: Icons.delete_outline_rounded,
          title: tx('Verilerinizin Kontrolü'),
          body: tx('Garajınızdaki araçları istediğiniz zaman Ayarlar > Garajı Temizle yoluyla silebilir, ya da uygulamayı cihazınızdan kaldırarak tüm yerel verileri tamamen temizleyebilirsiniz.'),
        ),
        SizedBox(height: 8),
        _PolicyFooterNote(),
      ],
    );
  }
}

class _PolicyIntro extends StatelessWidget {
  const _PolicyIntro();

  @override
  Widget build(BuildContext context) {
    return Text(
      tx('Devam etmeden önce, OTOSİNYAL OBD2\'nin hangi izinleri neden istediğini ve verilerinizle ne yaptığını (ya da yapmadığını) kısaca özetliyoruz.'),
      style: TextStyle(
        color: Colors.white70,
        fontSize: 14,
        height: 1.5,
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _PolicySection({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.accent, size: 18),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: TextStyle(
                color: Colors.white60,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PolicyFooterNote extends StatelessWidget {
  const _PolicyFooterNote();

  @override
  Widget build(BuildContext context) {
    return Text(
      tx('"Devam Et"e bastığınızda yukarıdaki bilgileri okuduğunuzu onaylamış olursunuz. Bu ekran bir daha gösterilmez; gizlilik politikasını istediğiniz zaman Ayarlar\'dan tekrar okuyabilirsiniz.'),
      style: TextStyle(
        color: Colors.white54,
        fontSize: 11,
        fontStyle: FontStyle.italic,
        height: 1.4,
      ),
    );
  }
}

/// Ayarlar'dan erişilen, sadece okuma amaçlı gizlilik politikası görünümü.
/// Onay/red butonu yoktur — kullanıcı zaten kabul etmiş, burada sadece
/// tekrar okuyabilir.
class PrivacyPolicyReadOnlyScreen extends StatelessWidget {
  const PrivacyPolicyReadOnlyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          tx('Gizlilik Politikası'),
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: const _PolicyContent(),
        ),
      ),
    );
  }
}
