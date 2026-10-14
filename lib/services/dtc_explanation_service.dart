import 'dtc_dictionary.dart';
import 'oem_diagnostic_catalog.dart';
import 'package:otosinyal_obd2/l10n/tx.dart';

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
      code: 'P0299', title: tx('Turbo / süperşarj düşük basınç (Underboost)'), severity: tx('Yüksek'),
      possibleCauses: [tx('Basınç/şarj hortumunda kaçak'), tx('Intercooler kaçağı'), tx('Vakum hattı veya turbo aktüatörü'), tx('VNT geometrisinin sıkışması'), tx('MAP/boost sensörü hatalı okuma'), tx('Turbo aşınması')],
      checks: [tx('Hedef ve gerçek boost değerini aynı sürüşte karşılaştır'), tx('Şarj hattına kaçak testi uygula'), tx('Vakum/aktüatör hareketini kontrol et'), tx('MAP ve MAF değerlerini yük altında karşılaştır')],
      drivingAdvice: tx('Araç belirgin güçten düşüyorsa veya turbo sesi/duman anormalse yüksek yükten kaçın. Arıza nedeni netleşmeden uzun süre tam gaz kullanma.'),
    ),
    'P0401': DtcExplanation(
      code: 'P0401', title: tx('EGR akışı yetersiz'), severity: tx('Orta'),
      possibleCauses: [tx('EGR valfi kurumlu/sıkışmış'), tx('EGR kanalı tıkalı'), tx('MAF/MAP geri bildirimi hatalı'), tx('Vakum/aktüatör sorunu')],
      checks: [tx('EGR commanded ve EGR error değerlerini izle'), tx('MAF değişimini EGR komutuyla kıyasla'), tx('EGR kanalı ve valfini kontrol et')],
      drivingAdvice: tx('Genelde kısa süreli sürüş mümkündür; yoğun duman, tekleme veya limp mode varsa zorlamadan kontrol ettir.'),
    ),
    'P0300': DtcExplanation(
      code: 'P0300', title: tx('Rastgele / çoklu silindir misfire'), severity: tx('Yüksek'),
      possibleCauses: [tx('Ateşleme'), tx('Enjektör/yakıt'), 'Kompresyon', tx('Hava kaçağı'), tx('Sensör/zamanlama')],
      checks: [tx('Silindir bazlı misfire sayaçlarını izle'), tx('Yakıt trimleri/rail basıncı kontrol et'), tx('Bobin-buji/enjektör karşılaştırması yap')],
      drivingAdvice: tx('MIL yanıp sönüyorsa sürmeye devam etme; katalizör hasarı oluşabilir.'),
    ),
  };

  static Future<DtcExplanation> explain(String code, {String? brand}) async {
    final c = code.trim().toUpperCase();
    final curated = _curated[c];
    if (curated != null) return curated;
    final oem = await OemDiagnosticCatalog.lookupDtc(c, brand);
    final title = (oem?.description.trim().isNotEmpty ?? false) ? oem!.description : DtcDictionary.getDescription(c, brand: brand ?? '');
    final severityRaw = (oem?.severity ?? '').toLowerCase();
    final severity = severityRaw.contains('critical') || severityRaw.contains('high') ? tx('Yüksek') : severityRaw.contains('low') ? tx('Düşük') : tx('Orta');
    final causes = (oem?.possibleCauses.isNotEmpty ?? false) ? oem!.possibleCauses : [tx('Elektrik/konnektör problemi'), tx('Sensör veya aktüatör arızası'), tx('Mekanik veya hava/yakıt sistemi problemi')];
    return DtcExplanation(
      code: c, title: title, severity: severity, possibleCauses: causes,
      checks: [tx('Freeze-frame koşullarını incele'), tx('İlgili canlı veriyi ECU hedefiyle karşılaştır'), tx('Kablo/konnektör ve fiziksel sistemi kontrol et'), tx('Onarım sonrası DTC’yi silip tekrar tara')],
      drivingAdvice: severity == tx('Yüksek') ? tx('Belirgin performans kaybı, hararet, yağ basıncı veya yanıp sönen MIL varsa aracı zorlamadan durdurup kontrol ettir.') : tx('Araç normal davranıyorsa kontrollü sürüş mümkün olabilir; kod tekrar ediyorsa arızayı geciktirmeden kontrol ettir.'),
    );
  }
}
