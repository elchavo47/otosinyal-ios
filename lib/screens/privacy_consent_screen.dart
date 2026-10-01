import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:otosinyal_obd2/core/app_colors.dart';
import 'package:otosinyal_obd2/screens/root_screen.dart';
import 'package:otosinyal_obd2/services/privacy_consent_service.dart';

/// Uygulama açılışında (daha önce onaylanmadıysa) gösterilen gizlilik
/// politikası ekranı. Reddedilirse uygulama kullanılamaz hale gelir —
/// tek çıkış yolu politikayı tekrar açıp kabul etmektir.
class PrivacyConsentScreen extends StatefulWidget {
  const PrivacyConsentScreen({super.key});

  @override
  State<PrivacyConsentScreen> createState() => _PrivacyConsentScreenState();
}

class _PrivacyConsentScreenState extends State<PrivacyConsentScreen> {
  bool _isRejected = false;
  final ScrollController _scrollController = ScrollController();
  bool _scrolledToEnd = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_checkScrollEnd);
  }

  void _checkScrollEnd() {
    if (_scrolledToEnd) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 24) {
      setState(() => _scrolledToEnd = true);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_checkScrollEnd);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    await PrivacyConsentService.setAccepted(true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const RootScreen()),
    );
  }

  void _reject() {
    setState(() => _isRejected = true);
  }

  void _reconsider() {
    setState(() {
      _isRejected = false;
      _scrolledToEnd = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isRejected) {
      return _RejectedBlockScreen(onReconsider: _reconsider);
    }

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
                  const Expanded(
                    child: Text(
                      'Gizlilik ve İzinler',
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
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: const _PolicyContent(),
                ),
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_scrolledToEnd)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        'Devam etmek için metni sonuna kadar okuyun',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _reject,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: Colors.white24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Reddet',
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _scrolledToEnd ? _accept : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            disabledBackgroundColor:
                                AppColors.accent.withValues(alpha: 0.25),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Kabul Ediyorum',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
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
        const _PolicySection(
          icon: Icons.bluetooth_rounded,
          title: 'Bluetooth İzni',
          body: 'OTOSİNYAL OBD2, aracınızdaki ELM327 OBD2 cihazına '
              'bağlanmak ve gerçek zamanlı motor verisi (hız, RPM, sıcaklık, '
              'arıza kodları vb.) okumak için Bluetooth iznine ihtiyaç duyar. '
              'Bu izin olmadan uygulamanın temel işlevi (araç verisi okuma) '
              'çalışmaz.',
        ),
        if (Platform.isAndroid)
          _PolicySection(
            icon: Icons.location_on_outlined,
            title: 'Konum İzni',
            body: 'Android işletim sistemi, Bluetooth cihaz taraması '
                'yapabilmek için konum iznini zorunlu kılar. OTOSİNYAL OBD2 '
                'konum bilginizi kaydetmez, sunucuya göndermez veya '
                'başka bir amaçla kullanmaz — bu izin yalnızca Bluetooth '
                'taramasının teknik bir gereksinimidir.',
          ),
        _PolicySection(
          icon: Icons.storage_rounded,
          title: 'Cihazda Saklanan Veriler',
          body: 'Garajınıza eklediğiniz araç bilgileri (marka, model, '
              'plaka, yıl, yakıt tipi) yalnızca telefonunuzda, cihaz '
              'içi depolamada tutulur. Bu veriler hiçbir sunucuya '
              'gönderilmez, hiçbir üçüncü tarafla paylaşılmaz.',
        ),
        _PolicySection(
          icon: Icons.wifi_off_rounded,
          title: 'İnternet Kullanımı',
          body: 'Uygulama, araç verisi okuma ve arıza kodu görüntüleme '
              'işlevleri için internet bağlantısına ihtiyaç duymaz. '
              'Tüm işlemler cihazınızda ve doğrudan Bluetooth üzerinden '
              'aracınızla gerçekleşir.',
        ),
        _PolicySection(
          icon: Icons.groups_outlined,
          title: 'Üçüncü Taraflarla Paylaşım',
          body: 'Verileriniz reklam, analiz veya pazarlama amacıyla '
              'hiçbir üçüncü tarafla paylaşılmaz veya satılmaz. Ayrıntılı '
              'teşhis logu ya da PDF raporu paylaş düğmesine bastığınızda '
              'Android/iOS sistem paylaşım ekranı açılır; VIN, ECU cevabı ve '
              'araç verileri seçtiğiniz uygulamaya gidebilir.',
        ),
        _PolicySection(
          icon: Icons.wifi_rounded,
          title: 'Wi‑Fi / USB İletişimi',
          body: 'Wi‑Fi OBD bağlantısı yalnızca girdiğiniz IP ve TCP portuna, '
              'USB OTG bağlantısı ise seçtiğiniz kabloya komut gönderir. '
              'OTOSİNYAL bu verileri otomatik olarak bir sunucuya yüklemez.',
        ),
        _PolicySection(
          icon: Icons.delete_outline_rounded,
          title: 'Verilerinizin Kontrolü',
          body: 'Garajınızdaki araçları istediğiniz zaman Ayarlar > '
              'Garajı Temizle yoluyla silebilir, ya da uygulamayı '
              'cihazınızdan kaldırarak tüm yerel verileri tamamen '
              'temizleyebilirsiniz.',
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
      'Devam etmeden önce, OTOSİNYAL OBD2\'nin hangi izinleri neden '
      'istediğini ve verilerinizle ne yaptığını (ya da yapmadığını) '
      'kısaca özetliyoruz.',
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
      '"Kabul Ediyorum"a bastığınızda yukarıdaki koşulları okuduğunuzu '
      've kabul ettiğinizi onaylamış olursunuz. Bu ekran bir daha '
      'gösterilmez.',
      style: TextStyle(
        color: Colors.white30,
        fontSize: 11,
        fontStyle: FontStyle.italic,
        height: 1.4,
      ),
    );
  }
}

/// Kullanıcı politikayı reddettiğinde gösterilen kilit ekranı.
/// Uygulamanın hiçbir başka ekranına geçiş yolu yoktur — tek seçenek
/// politikayı tekrar gözden geçirmektir.
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
        title: const Text(
          'Gizlilik Politikası',
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

class _RejectedBlockScreen extends StatelessWidget {
  final VoidCallback onReconsider;
  const _RejectedBlockScreen({required this.onReconsider});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.block_rounded,
                size: 64,
                color: AppColors.warning.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 20),
              const Text(
                'Devam edilemiyor',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'OTOSİNYAL OBD2\'yi kullanabilmek için gizlilik '
                'politikasını kabul etmeniz gerekiyor. Kabul etmeden '
                'uygulamanın hiçbir bölümüne erişilemez.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: onReconsider,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Politikayı Tekrar Gör',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
