import 'dtc_dictionary.dart';
import 'oem_diagnostic_catalog.dart';

class DtcExplanation {
  final String code;
  final String title;
  final String severity;
  final List<String> possibleCauses;
  final List<String> checks;
  final String drivingAdvice;

  const DtcExplanation({required this.code, required this.title, required this.severity, required this.possibleCauses, required this.checks, required this.drivingAdvice});
}

class DtcExplanationService {
  static const Map<String, DtcExplanation> _curated = {
    'P0299': DtcExplanation(
      code: 'P0299', title: 'Turbo / süperşarj düşük basınç (Underboost)', severity: 'Yüksek',
      possibleCauses: ['Basınç/şarj hortumunda kaçak', 'Intercooler kaçağı', 'Vakum hattı veya turbo aktüatörü', 'VNT geometrisinin sıkışması', 'MAP/boost sensörü hatalı okuma', 'Turbo aşınması'],
      checks: ['Hedef ve gerçek boost değerini aynı sürüşte karşılaştır', 'Şarj hattına kaçak testi uygula', 'Vakum/aktüatör hareketini kontrol et', 'MAP ve MAF değerlerini yük altında karşılaştır'],
      drivingAdvice: 'Araç belirgin güçten düşüyorsa veya turbo sesi/duman anormalse yüksek yükten kaçın. Arıza nedeni netleşmeden uzun süre tam gaz kullanma.',
    ),
    'P0401': DtcExplanation(
      code: 'P0401', title: 'EGR akışı yetersiz', severity: 'Orta',
      possibleCauses: ['EGR valfi kurumlu/sıkışmış', 'EGR kanalı tıkalı', 'MAF/MAP geri bildirimi hatalı', 'Vakum/aktüatör sorunu'],
      checks: ['EGR commanded ve EGR error değerlerini izle', 'MAF değişimini EGR komutuyla kıyasla', 'EGR kanalı ve valfini kontrol et'],
      drivingAdvice: 'Genelde kısa süreli sürüş mümkündür; yoğun duman, tekleme veya limp mode varsa zorlamadan kontrol ettir.',
    ),
    'P0300': DtcExplanation(
      code: 'P0300', title: 'Rastgele / çoklu silindir misfire', severity: 'Yüksek',
      possibleCauses: ['Ateşleme', 'Enjektör/yakıt', 'Kompresyon', 'Hava kaçağı', 'Sensör/zamanlama'],
      checks: ['Silindir bazlı misfire sayaçlarını izle', 'Yakıt trimleri/rail basıncı kontrol et', 'Bobin-buji/enjektör karşılaştırması yap'],
      drivingAdvice: 'MIL yanıp sönüyorsa sürmeye devam etme; katalizör hasarı oluşabilir.',
    ),
  };

  static Future<DtcExplanation> explain(String code, {String? brand}) async {
    final c = code.trim().toUpperCase();
    final curated = _curated[c];
    if (curated != null) return curated;
    final oem = await OemDiagnosticCatalog.lookupDtc(c, brand);
    final title = (oem?.description.trim().isNotEmpty ?? false) ? oem!.description : DtcDictionary.getDescription(c, brand: brand ?? '');
    final severityRaw = (oem?.severity ?? '').toLowerCase();
    final severity = severityRaw.contains('critical') || severityRaw.contains('high') ? 'Yüksek' : severityRaw.contains('low') ? 'Düşük' : 'Orta';
    final causes = (oem?.possibleCauses.isNotEmpty ?? false) ? oem!.possibleCauses : const ['Elektrik/konnektör problemi', 'Sensör veya aktüatör arızası', 'Mekanik veya hava/yakıt sistemi problemi'];
    return DtcExplanation(
      code: c, title: title, severity: severity, possibleCauses: causes,
      checks: const ['Freeze-frame koşullarını incele', 'İlgili canlı veriyi ECU hedefiyle karşılaştır', 'Kablo/konnektör ve fiziksel sistemi kontrol et', 'Onarım sonrası DTC’yi silip tekrar tara'],
      drivingAdvice: severity == 'Yüksek' ? 'Belirgin performans kaybı, hararet, yağ basıncı veya yanıp sönen MIL varsa aracı zorlamadan durdurup kontrol ettir.' : 'Araç normal davranıyorsa kontrollü sürüş mümkün olabilir; kod tekrar ediyorsa arızayı geciktirmeden kontrol ettir.',
    );
  }
}
