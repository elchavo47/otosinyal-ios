import '../models/vehicle.dart';
import '../providers/obd_provider.dart';

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
        ? 'Henüz ECU modül keşfi yapılmadı.'
        : obd.ecuModules
            .map((e) => '${e.canId} ${e.label} | ${e.ecuName ?? '-'} | CAL ${e.calibrationId ?? '-'}')
            .join('\n');

    return '''
Sen OTOSİNYAL araç teşhis asistanısın. Yalnızca aşağıdaki gerçek OBD/araç verisini kullan.
Olmayan sensör değerlerini, DTC'leri veya parça arızalarını uydurma. Kesin tanı yerine kanıt düzeyini belirt.
Yanıtı Türkçe ve anlaşılır ver.

KULLANICI SORUSU
$question

ARAÇ
Marka/model: ${vehicle.displayName}
Yıl: ${vehicle.year ?? '-'}
Yakıt: ${vehicle.fuelType.label}
Motor: ${vehicle.engine.isEmpty ? '-' : vehicle.engine}
Motor kodu: ${vehicle.engineCode.isEmpty ? '-' : vehicle.engineCode}
VIN: ${obd.detectedVin ?? '-'}
Protokol: ${obd.protocolName ?? '-'}

CANLI OBD VERİSİ
Hız: ${obd.data.speed} km/h
RPM: ${obd.data.rpm}
Soğutma suyu: ${obd.data.engineTemp} °C
MAP: ${obd.data.boostKpa ?? '-'} kPa
Turbo gerçek: ${obd.actualBoostGaugeBarPid70 ?? obd.boostGaugeBar ?? '-'} bar
Turbo hedef: ${obd.commandedBoostGaugeBar ?? '-'} bar
Akü/şarj: ${(obd.controlModuleVoltage ?? obd.data.voltage).toStringAsFixed(1)} V
MAF: ${obd.mafGps?.toStringAsFixed(1) ?? '-'} g/s
EGR komutu: ${obd.egrCommandedPercent?.toStringAsFixed(1) ?? '-'} %
EGR sapması: ${obd.egrErrorPercent?.toStringAsFixed(1) ?? '-'} %
Yakıt rayı: ${obd.fuelRailPressureKpa == null ? '-' : (obd.fuelRailPressureKpa! / 1000).toStringAsFixed(1)} MPa
Yakıt debisi: ${obd.fuelRateLph?.toStringAsFixed(2) ?? '-'} L/h
Yağ sıcaklığı: ${obd.oilTempC ?? '-'} °C

DTC
Kayıtlı: ${stored.isEmpty ? 'Yok' : stored}
Bekleyen: ${pending.isEmpty ? 'Yok' : pending}
Kalıcı: ${permanent.isEmpty ? 'Yok' : permanent}
MIL: ${obd.milOn == null ? 'Bilinmiyor' : obd.milOn! ? 'Açık' : 'Kapalı'}

READINESS
${obd.readiness.supported == 0 ? 'Veri yok' : '${obd.readiness.completed}/${obd.readiness.supported} tamam'}
Eksik monitorler: ${obd.readiness.incomplete.isEmpty ? 'Yok' : obd.readiness.incomplete.join(', ')}

ECU MODÜLLERİ
$modules

OTOSİNYAL UYARILARI
${obd.healthWarnings.isEmpty ? 'Yok' : obd.healthWarnings.join('\n')}

Yanıt formatı:
1. En olası açıklama
2. Kanıtlar
3. Kontrol edilmesi gerekenler (öncelik sırasıyla)
4. Güvenli doğrulama adımları
5. Acil kullanım riski varsa açıkça belirt
'''.trim();
  }

  static String localPreAnalysis(ObdProvider obd) {
    final out = <String>[];
    if (obd.dtcEntries.isNotEmpty) {
      out.add('${obd.dtcEntries.length} DTC kaydı bulundu; önce kayıtlı ve bekleyen kodları birlikte değerlendirmek gerekir.');
    } else {
      out.add('Şu an uygulamada kayıtlı DTC görünmüyor. Arıza lambası yanmadan oluşan performans sorunları canlı veriyle doğrulanmalı.');
    }
    if (obd.healthWarnings.isNotEmpty) out.addAll(obd.healthWarnings);
    if (obd.readiness.supported > 0 && !obd.readiness.allReady) {
      out.add('Bazı readiness monitörleri tamamlanmamış; yakın zamanda DTC silme/akü kesme olduysa normal olabilir.');
    }
    if (obd.ecuModules.isEmpty) {
      out.add('Daha güçlü analiz için ECU Modülleri taramasını çalıştır.');
    }
    return out.join('\n\n');
  }
}
