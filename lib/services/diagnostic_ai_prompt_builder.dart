import '../models/vehicle.dart';
import '../providers/obd_provider.dart';
import 'package:otosinyal_obd2/l10n/tx.dart';

class DiagnosticAiPromptBuilder {
  static String build({
    required Vehicle vehicle,
    required ObdProvider obd,
    required String question,
  }) {
    final stored = obd.dtcEntries
        .where((e) => e.status == DtcStatus.stored)
        .map((e) => e.code)
        .join(', ');
    final pending = obd.dtcEntries
        .where((e) => e.status == DtcStatus.pending)
        .map((e) => e.code)
        .join(', ');
    final permanent = obd.dtcEntries
        .where((e) => e.status == DtcStatus.permanent)
        .map((e) => e.code)
        .join(', ');

    final modules = obd.ecuModules.isEmpty
        ? tx('Henüz ECU modül keşfi yapılmadı.')
        : obd.ecuModules
            .map((e) => '${e.canId} ${e.label} | ${e.ecuName ?? '-'} | CAL ${e.calibrationId ?? '-'}')
            .join('\n');

    return tx('\nSen OTOSİNYAL araç teşhis asistanısın. Yalnızca aşağıdaki gerçek OBD/araç verisini kullan.\nOlmayan sensör değerlerini, DTC\'leri veya parça arızalarını uydurma. Kesin tanı yerine kanıt düzeyini belirt.\nYanıtı Türkçe ve anlaşılır ver.\n\nKULLANICI SORUSU\n{0}\n\nARAÇ\nMarka/model: {1}\nYıl: {2}\nYakıt: {3}\nMotor: {4}\nMotor kodu: {5}\nVIN: {6}\nProtokol: {7}\n\nCANLI OBD VERİSİ\nHız: {8} km/h\nRPM: {9}\nSoğutma suyu: {10} °C\nMAP: {11} kPa\nTurbo gerçek: {12} bar\nTurbo hedef: {13} bar\nAkü/şarj: {14} V\nMAF: {15} g/s\nEGR komutu: {16} %\nEGR sapması: {17} %\nYakıt rayı: {18} MPa\nYakıt debisi: {19} L/h\nYağ sıcaklığı: {20} °C\n\nDTC\nKayıtlı: {21}\nBekleyen: {22}\nKalıcı: {23}\nMIL: {24}\n\nREADINESS\n{25}\nEksik monitorler: {26}\n\nECU MODÜLLERİ\n{27}\n\nOTOSİNYAL UYARILARI\n{28}\n\nYanıt formatı:\n1. En olası açıklama\n2. Kanıtlar\n3. Kontrol edilmesi gerekenler (öncelik sırasıyla)\n4. Güvenli doğrulama adımları\n5. Acil kullanım riski varsa açıkça belirt\n', [question, vehicle.displayName, vehicle.year ?? '-', vehicle.fuelType.label, vehicle.engine.isEmpty ? '-' : vehicle.engine, vehicle.engineCode.isEmpty ? '-' : vehicle.engineCode, obd.detectedVin ?? '-', obd.protocolName ?? '-', obd.data.speed, obd.data.rpm, obd.data.engineTemp, obd.data.boostKpa ?? '-', obd.actualBoostGaugeBarPid70 ?? obd.boostGaugeBar ?? '-', obd.commandedBoostGaugeBar ?? '-', (obd.controlModuleVoltage ?? obd.data.voltage).toStringAsFixed(1), obd.mafGps?.toStringAsFixed(1) ?? '-', obd.egrCommandedPercent?.toStringAsFixed(1) ?? '-', obd.egrErrorPercent?.toStringAsFixed(1) ?? '-', obd.fuelRailPressureKpa == null ? '-' : (obd.fuelRailPressureKpa! / 1000).toStringAsFixed(1), obd.fuelRateLph?.toStringAsFixed(2) ?? '-', obd.oilTempC ?? '-', stored.isEmpty ? tx('Yok') : stored, pending.isEmpty ? tx('Yok') : pending, permanent.isEmpty ? tx('Yok') : permanent, obd.milOn == null ? tx('Bilinmiyor') : obd.milOn! ? tx('Açık') : tx('Kapalı'), obd.readiness.supported == 0 ? tx('Veri yok') : tx('{0}/{1} tamam', [obd.readiness.completed, obd.readiness.supported]), obd.readiness.incomplete.isEmpty ? tx('Yok') : obd.readiness.incomplete.join(', '), modules, obd.healthWarnings.isEmpty ? tx('Yok') : obd.healthWarnings.join('\n')]).trim();
  }

  static String localPreAnalysis(ObdProvider obd) {
    final out = <String>[];
    if (obd.dtcEntries.isNotEmpty) {
      out.add(tx('{0} DTC kaydı bulundu; önce kayıtlı ve bekleyen kodları birlikte değerlendirmek gerekir.', [obd.dtcEntries.length]));
    } else {
      out.add(tx('Şu an uygulamada kayıtlı DTC görünmüyor. Arıza lambası yanmadan oluşan performans sorunları canlı veriyle doğrulanmalı.'));
    }
    if (obd.healthWarnings.isNotEmpty) out.addAll(obd.healthWarnings);
    if (obd.readiness.supported > 0 && !obd.readiness.allReady) {
      out.add(tx('Bazı readiness monitörleri tamamlanmamış; yakın zamanda DTC silme/akü kesme olduysa normal olabilir.'));
    }
    if (obd.ecuModules.isEmpty) {
      out.add(tx('Daha güçlü analiz için ECU Modülleri taramasını çalıştır.'));
    }
    return out.join('\n\n');
  }
}
