import 'package:flutter/material.dart';
import 'package:otosinyal_obd2/core/app_colors.dart';
import 'package:otosinyal_obd2/l10n/tx.dart';

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  static final features = <(IconData, String, String)>[
    (Icons.health_and_safety_rounded, tx('Tek Tuş Akıllı Tarama'), tx('DTC, readiness ve canlı verileri tek teşhis özetinde birleştirir.')),
    (Icons.show_chart_rounded, tx('Canlı Grafikler ve Sürüş Logu'), tx('Desteklenen PID’leri zaman çizelgesinde kaydet, karşılaştır ve dışa aktar.')),
    (Icons.camera_alt_outlined, 'Freeze Frame + Mode 06', tx('ECU destekliyorsa arıza anı verisini ve onboard test sonuçlarını gösterir.')),
    (Icons.fact_check_outlined, 'I/M Readiness', tx('Emisyon monitörlerini Hazır / Hazır Değil / Desteklenmiyor olarak ayırır.')),
    (Icons.memory_rounded, tx('ECU Kimliği'), tx('Desteklenen araçlarda VIN, CALID, CVN ve ECU kimliklerini okur.')),
    (Icons.troubleshoot_rounded, tx('Gelişmiş DTC Analizi'), tx('Türkçe açıklama, önem seviyesi, olası nedenler ve silme sonrası doğrulama.')),
    (Icons.bluetooth_searching_rounded, tx('Adaptör ve Bağlantı Doktoru'), tx('ELM/OBD bağlantı zincirinde hatanın hangi aşamada olduğunu anlaşılır gösterir.')),
    (Icons.battery_charging_full_rounded, tx('Akü / Şarj Analizi'), tx('Gerçek ECU/adaptör voltajını çalışma durumuna göre değerlendirir.')),
    (Icons.speed_rounded, tx('Turbo Analizi'), tx('MAP/barometrik veriyi izler; hedef basıncı yalnızca ECU gerçekten sağlarsa gösterir.')),
    (Icons.car_repair_rounded, 'VAG Lab', tx('ECU profili destekliyorsa DPF/EGR, requested/actual ve üretici-özel ölçümlere hazırlanır.')),
    (Icons.picture_as_pdf_rounded, tx('Premium Teşhis Raporu'), tx('Araç, tarama, canlı veri ve geçmişi okunabilir raporda toplar.')),
    (Icons.compare_arrows_rounded, tx('Geçmiş Karşılaştırma'), tx('Yeni, devam eden ve kaybolan arıza kodlarını araç bazında karşılaştırır.')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Premium')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 28), children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF3A0A0F), Color(0xFF160D0E), Color(0xFF0B0B0B)]),
            border: Border.all(color: AppColors.accentBright.withValues(alpha: .55)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(Icons.workspace_premium_rounded, color: AppColors.accentBright, size: 32), Spacer(), _PremiumPill()]),
            SizedBox(height: 18),
            Text(tx('Aracını sadece okuma.\nGerçekten analiz et.'), style: TextStyle(color: Colors.white, fontSize: 25, height: 1.08, fontWeight: FontWeight.w900)),
            SizedBox(height: 10),
            Text(tx('Premium; ECU’nun gerçekten sunduğu veriyi daha derin analiz, kayıt ve raporlama araçlarıyla kullanır. Desteklenmeyen değer üretmez.'), style: TextStyle(color: Colors.white70, height: 1.45)),
          ]),
        ),
        const SizedBox(height: 18),
        Text(tx('PREMIUM İLE GELENLER'), style: TextStyle(color: AppColors.accentBright, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: .7)),
        const SizedBox(height: 10),
        ...features.map((f) => _Feature(icon: f.$1, title: f.$2, text: f.$3)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF302526))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.verified_user_outlined, color: Colors.white54, size: 20), SizedBox(width: 10),
            Expanded(child: Text(tx('Premium satın alma, mağaza sürümünde Google Play Billing / App Store In‑App Purchase ve güvenli üyelik doğrulaması bağlandığında etkinleşir.'), style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.4))),
          ]),
        ),
        const SizedBox(height: 14),
        SizedBox(height: 54, child: FilledButton.icon(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tx('Premium satın alma mağaza ödeme sistemi bağlandığında aktif olacak.')))),
          icon: const Icon(Icons.workspace_premium_rounded),
          label: Text(tx('PREMIUM OL'), style: TextStyle(fontWeight: FontWeight.w900)),
        )),
      ]),
    );
  }
}

class _PremiumPill extends StatelessWidget { const _PremiumPill(); @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: AppColors.accentBright.withValues(alpha: .12), borderRadius: BorderRadius.circular(99)), child: Text(tx('PRO TEŞHİS'), style: TextStyle(color: AppColors.accentBright, fontWeight: FontWeight.w900, fontSize: 10))); }
class _Feature extends StatelessWidget { const _Feature({required this.icon, required this.title, required this.text}); final IconData icon; final String title,text; @override Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 9), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFF302526))), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 38,height:38,decoration:BoxDecoration(color:AppColors.accentBright.withValues(alpha:.10),borderRadius:BorderRadius.circular(11)),child:Icon(icon,color:AppColors.accentBright,size:20)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w800)),const SizedBox(height:4),Text(text,style:const TextStyle(color:Colors.white60,fontSize:12,height:1.35))]))])); }
