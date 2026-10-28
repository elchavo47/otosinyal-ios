import 'dart:typed_data';
import 'ios_share_origin.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../models/obd_data.dart';
import 'dtc_dictionary.dart';
import '../models/vehicle.dart';
import '../providers/obd_provider.dart';
import 'package:otosinyal_obd2/l10n/tx.dart';

class DiagnosticReportService {
  static const _red = PdfColor(0.898, 0.106, 0.137);
  static const _dark = PdfColor(0.055, 0.055, 0.059);
  static const _muted = PdfColor(0.43, 0.43, 0.46);
  static const _green = PdfColor(0.22, 0.72, 0.38);
  static const _orange = PdfColor(1.0, 0.56, 0.12);
  static const _soft = PdfColor(0.965, 0.965, 0.97);

  static Future<File> createPdf({
    required Vehicle vehicle,
    required ObdProvider obd,
    required ObdData data,
  }) async {
    final bytes = await buildPdfBytes(vehicle: vehicle, obd: obd, data: data);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${_filename(vehicle, DateTime.now(), 'pdf')}');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// PDF içeriğini üretir (dosyaya yazmadan). Testlerde de kullanılır.
  static Future<Uint8List> buildPdfBytes({
    required Vehicle vehicle,
    required ObdProvider obd,
    required ObdData data,
  }) async {
    await DtcDictionary.initialize();
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Regular.ttf'));
    final semi = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-SemiBold.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Bold.ttf'));
    final logo = pw.MemoryImage((await rootBundle.load('assets/icons/report_logo.png')).buffer.asUint8List());
    final doc = pw.Document(theme: pw.ThemeData.withFont(base: regular, bold: bold));
    final now = DateTime.now();

    final stored = obd.dtcEntries.where((e) => e.status == DtcStatus.stored).map((e) => e.code).toList();
    final pending = obd.dtcEntries.where((e) => e.status == DtcStatus.pending).map((e) => e.code).toList();
    final permanent = obd.dtcEntries.where((e) => e.status == DtcStatus.permanent).map((e) => e.code).toList();
    final voltage = obd.controlModuleVoltage ?? data.voltage;
    final warnings = List<String>.from(obd.healthWarnings);
    final healthScore = _healthScore(obd, data);

    pw.Widget sectionTitle(String title, {String? subtitle}) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 14, bottom: 7),
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Container(width: 4, height: 19, decoration: const pw.BoxDecoration(color: _red, borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)))),
            pw.SizedBox(width: 8),
            pw.Text(title, style: pw.TextStyle(font: bold, fontSize: 12.5, color: _dark)),
            if (subtitle != null) ...[
              pw.SizedBox(width: 8),
              pw.Expanded(child: pw.Text(subtitle, style: pw.TextStyle(font: regular, fontSize: 7.5, color: _muted))),
            ],
          ]),
        );

    pw.Widget metric(String label, String value, {PdfColor? valueColor}) => pw.Container(
          padding: const pw.EdgeInsets.all(9),
          decoration: pw.BoxDecoration(color: _soft, borderRadius: pw.BorderRadius.circular(7)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(label.toUpperCase(), style: pw.TextStyle(font: semi, fontSize: 6.3, color: _muted, letterSpacing: .7)),
            pw.SizedBox(height: 4),
            pw.Text(value, style: pw.TextStyle(font: bold, fontSize: 11, color: valueColor ?? _dark)),
          ]),
        );

    pw.Widget infoRow(String label, String value) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Row(children: [
            pw.SizedBox(width: 95, child: pw.Text(label, style: pw.TextStyle(font: semi, fontSize: 7.5, color: _muted))),
            pw.Expanded(child: pw.Text(value, style: pw.TextStyle(font: regular, fontSize: 8.2, color: _dark))),
          ]),
        );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(30, 28, 30, 30),
        header: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 10),
          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColor(0.9, 0.9, 0.91), width: .8))),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Row(children: [
              pw.ClipRRect(horizontalRadius: 8, verticalRadius: 8, child: pw.SizedBox(width: 36, height: 36, child: pw.Image(logo, fit: pw.BoxFit.cover))),
              pw.SizedBox(width: 9),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(tx('OTOSİNYAL'), style: pw.TextStyle(font: bold, fontSize: 16, color: _dark, letterSpacing: 1.1)),
                pw.Text(tx('AKILLI ARAÇ TEŞHİS RAPORU'), style: pw.TextStyle(font: semi, fontSize: 6.5, color: _red, letterSpacing: 1.1)),
              ]),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text(_formatDate(now), style: pw.TextStyle(font: semi, fontSize: 7.5, color: _dark)),
              pw.SizedBox(height: 2),
              pw.Text(tx('Rapor ID: {0}', [now.millisecondsSinceEpoch]), style: pw.TextStyle(font: regular, fontSize: 6.5, color: _muted)),
            ]),
          ]),
        ),
        footer: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColor(0.9, 0.9, 0.91), width: .7))),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text(tx('AYD WORKS • OTOSİNYAL OBD2'), style: pw.TextStyle(font: semi, fontSize: 6.5, color: _muted)),
            pw.Text(tx('Sayfa {0} / {1}', [ctx.pageNumber, ctx.pagesCount]), style: pw.TextStyle(font: regular, fontSize: 6.5, color: _muted)),
          ]),
        ),
        build: (_) => [
          pw.SizedBox(height: 15),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(color: _dark, borderRadius: pw.BorderRadius.circular(12)),
            child: pw.Row(children: [
              pw.Container(
                width: 68,
                height: 68,
                alignment: pw.Alignment.center,
                decoration: pw.BoxDecoration(color: _red, borderRadius: pw.BorderRadius.circular(10)),
                child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
                  pw.Text('$healthScore', style: pw.TextStyle(font: bold, fontSize: 24, color: PdfColors.white)),
                  pw.Text('/ 100', style: pw.TextStyle(font: semi, fontSize: 7, color: PdfColors.white)),
                ]),
              ),
              pw.SizedBox(width: 15),
              pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(vehicle.displayName.toUpperCase(), style: pw.TextStyle(font: bold, fontSize: 17, color: PdfColors.white)),
                pw.SizedBox(height: 4),
                pw.Text('${vehicle.year ?? '-'} • ${vehicle.fuelType.label} • ${vehicle.engine.isEmpty ? tx('Motor bilgisi yok') : vehicle.engine}', style: pw.TextStyle(font: regular, fontSize: 8.5, color: PdfColor(0.78, 0.78, 0.8))),
                pw.SizedBox(height: 7),
                pw.Text(_healthLabel(healthScore, warnings), style: pw.TextStyle(font: semi, fontSize: 8.5, color: healthScore >= 80 ? _green : healthScore >= 60 ? _orange : _red)),
              ])),
            ]),
          ),

          sectionTitle(tx('ARAÇ VE BAĞLANTI')),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: const PdfColor(0.9, 0.9, 0.91)), borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Column(children: [
              infoRow(tx('VIN / Şase No'), obd.detectedVin ?? tx('ECU’dan okunamadı')),
              infoRow(tx('Plaka'), vehicle.plate.isEmpty ? '-' : vehicle.plate),
              infoRow(tx('Motor kodu'), vehicle.engineCode.isEmpty ? '-' : vehicle.engineCode),
              infoRow(tx('Şanzıman'), vehicle.transmission.isEmpty ? '-' : vehicle.transmission),
              infoRow(tx('OBD protokolü'), obd.protocolName ?? obd.adapterInfo.protocol),
              infoRow(tx('Adaptör'), '${obd.adapterInfo.identity} ${obd.adapterInfo.description == '-' ? '' : '• ${obd.adapterInfo.description}'}'),
              infoRow(tx('Adaptör kalite'), obd.adapterQualityScore == 0 ? tx('Ölçüm bekleniyor') : tx('{0}/100 • {1} ms ortalama', [obd.adapterQualityScore, obd.averageCommandLatencyMs.toStringAsFixed(0)])),
            ]),
          ),

          sectionTitle(tx('GENEL DURUM')),
          pw.Row(children: [
            pw.Expanded(child: metric('DTC', '${stored.length + pending.length + permanent.length}', valueColor: stored.isEmpty ? _green : _red)),
            pw.SizedBox(width: 8),
            pw.Expanded(child: metric('MIL / Check Engine', obd.milOn == null ? tx('Bilinmiyor') : obd.milOn! ? tx('AÇIK') : tx('KAPALI'), valueColor: obd.milOn == true ? _red : _green)),
            pw.SizedBox(width: 8),
            pw.Expanded(child: metric('Readiness', obd.readiness.supported == 0 ? tx('Veri yok') : '${obd.readiness.completed}/${obd.readiness.supported}', valueColor: obd.readiness.allReady ? _green : _orange)),
            pw.SizedBox(width: 8),
            pw.Expanded(child: metric('ECU', '${obd.ecuModules.length}')),
          ]),

          sectionTitle(tx('CANLI VERİ'), subtitle: tx('Rapor oluşturulduğu anda ECU’dan alınan snapshot')),
          pw.Table(
            border: pw.TableBorder.all(color: const PdfColor(0.9, 0.9, 0.91), width: .6),
            columnWidths: const {0: pw.FlexColumnWidth(1.5), 1: pw.FlexColumnWidth(1), 2: pw.FlexColumnWidth(1.5), 3: pw.FlexColumnWidth(1)},
            children: [
              _metricRow(tx('Motor devri'), '${data.rpm} rpm', tx('Hız'), '${data.speed} km/h', regular, semi),
              _metricRow(tx('Soğutma suyu'), '${data.engineTemp} °C', tx('Akü / şarj'), '${voltage.toStringAsFixed(1)} V', regular, semi),
              _metricRow('MAP', '${data.boostKpa ?? '-'} kPa', 'MAF', obd.mafGps == null ? '-' : '${obd.mafGps!.toStringAsFixed(1)} g/s', regular, semi),
              _metricRow(tx('Turbo gerçek'), _bar(obd.actualBoostGaugeBarPid70 ?? obd.boostGaugeBar), tx('Turbo hedef'), _bar(obd.commandedBoostGaugeBar), regular, semi),
              _metricRow(tx('EGR komutu'), _percent(obd.egrCommandedPercent), tx('EGR sapması'), _percent(obd.egrErrorPercent), regular, semi),
              _metricRow(tx('Yakıt rayı'), obd.fuelRailPressureKpa == null ? '-' : '${(obd.fuelRailPressureKpa! / 1000).toStringAsFixed(1)} MPa', tx('Yakıt debisi'), obd.fuelRateLph == null ? '-' : '${obd.fuelRateLph!.toStringAsFixed(2)} L/h', regular, semi),
              _metricRow(tx('Yağ sıcaklığı'), obd.oilTempC == null ? '-' : '${obd.oilTempC} °C', tx('Motor yükü'), obd.engineLoadPercent == null ? '-' : '${obd.engineLoadPercent} %', regular, semi),
            ],
          ),

          sectionTitle(tx('ARIZA KODLARI')),
          _dtcBlock(tx('KAYITLI'), stored, _red, regular, semi),
          pw.SizedBox(height: 6),
          _dtcBlock(tx('BEKLEYEN'), pending, _orange, regular, semi),
          pw.SizedBox(height: 6),
          _dtcBlock(tx('KALICI'), permanent, _muted, regular, semi),
          if (obd.dtcEntries.isNotEmpty) ...[
            sectionTitle(tx('DTC AÇIKLAMALARI'), subtitle: tx('Açıklamalar olası nedenlerdir; kesin teşhis değildir.')),
            ...obd.dtcEntries.map((entry) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 5),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('${entry.code} • ${entry.status.label}',
                    style: pw.TextStyle(font: semi, fontSize: 8, color: _dark)),
                pw.Text(DtcDictionary.getDescription(entry.code, brand: vehicle.brand),
                    style: pw.TextStyle(font: regular, fontSize: 7.5, color: _muted)),
              ]),
            )),
          ],

          if (obd.freezeFrame.hasData) ...[
            sectionTitle('FREEZE FRAME', subtitle: tx('ECU’nun arıza oluştuğu anda sakladığı değerler')),
            pw.Row(children: [
              pw.Expanded(child: metric(tx('Tetik DTC'), obd.freezeFrame.triggerDtc ?? '-')),
              pw.SizedBox(width: 7),
              pw.Expanded(child: metric('RPM', '${obd.freezeFrame.rpm ?? '-'}')),
              pw.SizedBox(width: 7),
              pw.Expanded(child: metric(tx('Hız'), '${obd.freezeFrame.speedKmh ?? '-'} km/h')),
              pw.SizedBox(width: 7),
              pw.Expanded(child: metric(tx('Su'), '${obd.freezeFrame.coolantC ?? '-'} °C')),
            ]),
          ],

          sectionTitle(tx('ECU MODÜLLERİ'), subtitle: tx('Mode 09 üzerinden yanıt veren OBD-II ECU kimlikleri')),
          if (obd.ecuModules.isEmpty)
            pw.Text(tx('ECU modül keşfi yapılmadı veya araç bu Mode 09 yöntemine cevap vermedi.'), style: pw.TextStyle(font: regular, fontSize: 8, color: _muted))
          else
            pw.Table(
              border: pw.TableBorder.all(color: const PdfColor(0.9, 0.9, 0.91), width: .6),
              columnWidths: const {0: pw.FlexColumnWidth(.7), 1: pw.FlexColumnWidth(1.4), 2: pw.FlexColumnWidth(1.8), 3: pw.FlexColumnWidth(1.7)},
              children: [
                pw.TableRow(decoration: const pw.BoxDecoration(color: _dark), children: [
                  _cell('CAN ID', semi, color: PdfColors.white),
                  _cell(tx('Modül'), semi, color: PdfColors.white),
                  _cell(tx('ECU adı'), semi, color: PdfColors.white),
                  _cell(tx('Kalibrasyon / CVN'), semi, color: PdfColors.white),
                ]),
                ...obd.ecuModules.map((e) => pw.TableRow(children: [
                      _cell(e.canId, bold),
                      _cell(e.label, regular),
                      _cell(e.ecuName ?? '-', regular),
                      _cell('${e.calibrationId ?? '-'}${e.cvn == null ? '' : '\nCVN ${e.cvn}'}', regular),
                    ])),
              ],
            ),

          sectionTitle(tx('READINESS / EMİSYON')),
          pw.Container(
            padding: const pw.EdgeInsets.all(11),
            decoration: pw.BoxDecoration(color: _soft, borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(obd.readiness.supported == 0 ? tx('Readiness verisi alınmadı.') : tx('{0}/{1} monitor tamamlandı.', [obd.readiness.completed, obd.readiness.supported]), style: pw.TextStyle(font: bold, fontSize: 9, color: _dark)),
              if (obd.readiness.incomplete.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Text(tx('Tamamlanmayan: {0}', [obd.readiness.incomplete.join(', ')]), style: pw.TextStyle(font: regular, fontSize: 7.5, color: _muted)),
              ],
              pw.SizedBox(height: 4),
              pw.Text('Mode 06: ${obd.mode06Raw.isEmpty ? tx('veri yok / okunmadı') : tx('{0} ham monitor satırı alındı', [obd.mode06Raw.length])}', style: pw.TextStyle(font: regular, fontSize: 7.5, color: _muted)),
            ]),
          ),

          if (obd.clearHistory.hasData) ...[
            sectionTitle(tx('İKİNCİ EL KONTROLÜ'), subtitle: tx('Arıza kodlarının en son ne zaman silindiğini gösteren ECU sayaçları')),
            pw.Container(
              padding: const pw.EdgeInsets.all(11),
              decoration: pw.BoxDecoration(
                color: obd.clearHistory.recentlyCleared ? const PdfColor(1.0, .94, .94) : _soft,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(
                  obd.clearHistory.recentlyCleared
                      ? tx('Dikkat: arıza kodları yakın zamanda silinmiş olabilir.')
                      : tx('Arıza kodlarının yakın zamanda silindiğine dair bir işaret yok.'),
                  style: pw.TextStyle(font: bold, fontSize: 9, color: obd.clearHistory.recentlyCleared ? _red : _green),
                ),
                pw.SizedBox(height: 5),
                if (obd.clearHistory.distanceSinceClearKm != null)
                  pw.Text(tx('Kodlar silindikten sonra gidilen mesafe: {0} km', [obd.clearHistory.distanceSinceClearKm]), style: pw.TextStyle(font: regular, fontSize: 7.5, color: _muted)),
                if (obd.clearHistory.warmUpsSinceClear != null)
                  pw.Text(tx('Kodlar silindikten sonraki ısınma döngüsü: {0}', [obd.clearHistory.warmUpsSinceClear! >= 255 ? '255+' : obd.clearHistory.warmUpsSinceClear]), style: pw.TextStyle(font: regular, fontSize: 7.5, color: _muted)),
                if (obd.clearHistory.minutesSinceClear != null)
                  pw.Text(tx('Kodlar silindikten sonraki motor çalışma süresi: {0} dk', [obd.clearHistory.minutesSinceClear]), style: pw.TextStyle(font: regular, fontSize: 7.5, color: _muted)),
                if (obd.clearHistory.milDistanceKm != null)
                  pw.Text(tx('Arıza lambası yanarken gidilen mesafe: {0} km', [obd.clearHistory.milDistanceKm]), style: pw.TextStyle(font: regular, fontSize: 7.5, color: _muted)),
              ]),
            ),
          ],

          if (warnings.isNotEmpty) ...[
            sectionTitle(tx('OTOSİNYAL UYARILARI')),
            ...warnings.map((w) => pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 5),
                  padding: const pw.EdgeInsets.all(9),
                  decoration: pw.BoxDecoration(color: const PdfColor(1.0, .965, .91), borderRadius: pw.BorderRadius.circular(7), border: pw.Border.all(color: const PdfColor(1.0, .82, .55), width: .5)),
                  child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Text('!', style: pw.TextStyle(font: bold, color: _orange)), pw.SizedBox(width: 7), pw.Expanded(child: pw.Text(w, style: pw.TextStyle(font: regular, fontSize: 8, color: _dark)))]),
                )),
          ],

          pw.SizedBox(height: 18),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(color: const PdfColor(.97, .97, .975), borderRadius: pw.BorderRadius.circular(7)),
            child: pw.Text(
              tx('Bu rapor ECU/OBD-II üzerinden sağlanan elektronik teşhis verilerini özetler. Mekanik ekspertiz veya üretici servis prosedürünün yerine geçmez. DTC silme işlemi readiness monitörlerini sıfırlayabilir; kalıcı DTC’ler ECU koşulları sağlanmadan zorla silinmez.'),
              style: pw.TextStyle(font: regular, fontSize: 6.7, color: _muted),
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  static Future<File> createJson({required Vehicle vehicle, required ObdProvider obd}) async {
    final now = DateTime.now();
    final map = <String, dynamic>{
      'report_type': 'OTOSINYAL Diagnostic Report',
      'generated_at': now.toIso8601String(),
      'vehicle': vehicle.toMap(),
      'vin': obd.detectedVin,
      'protocol': obd.protocolName,
      'adapter': {'identity': obd.adapterInfo.identity, 'description': obd.adapterInfo.description, 'voltage': obd.adapterInfo.voltage},
      'live': {
        'speed_kmh': obd.data.speed,
        'rpm': obd.data.rpm,
        'coolant_c': obd.data.engineTemp,
        'map_kpa': obd.data.boostKpa,
        'voltage': obd.controlModuleVoltage ?? obd.data.voltage,
        'maf_gps': obd.mafGps,
        'egr_command_percent': obd.egrCommandedPercent,
        'egr_error_percent': obd.egrErrorPercent,
        'fuel_rail_kpa': obd.fuelRailPressureKpa,
        'fuel_rate_lph': obd.fuelRateLph,
        'oil_temp_c': obd.oilTempC,
      },
      'dtc': obd.dtcEntries.map((e) => {'code': e.code, 'status': e.status.name}).toList(),
      'readiness': {'completed': obd.readiness.completed, 'supported': obd.readiness.supported, 'incomplete': obd.readiness.incomplete},
      'ecu_modules': obd.ecuModules.map((e) => e.toJson()).toList(),
      'warnings': obd.healthWarnings,
    };
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${_filename(vehicle, now, 'json')}');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(map), flush: true);
    return file;
  }

  static Future<void> createAndShare({required Vehicle vehicle, required ObdProvider obd}) async {
    final pdf = await createPdf(vehicle: vehicle, obd: obd, data: obd.data);
    await Share.shareXFiles([XFile(pdf.path)], subject: tx('OTOSİNYAL PDF Teşhis Raporu'), sharePositionOrigin: otoShareOrigin());
  }

  static pw.TableRow _metricRow(String a, String av, String b, String bv, pw.Font regular, pw.Font semi) => pw.TableRow(children: [
        _cell(a, semi, color: _muted),
        _cell(av, regular),
        _cell(b, semi, color: _muted),
        _cell(bv, regular),
      ]);

  static pw.Widget _cell(String text, pw.Font font, {PdfColor color = _dark}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 6),
        child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 7.2, color: color)),
      );

  static pw.Widget _dtcBlock(String title, List<String> codes, PdfColor color, pw.Font regular, pw.Font semi) => pw.Container(
        padding: const pw.EdgeInsets.all(9),
        decoration: pw.BoxDecoration(color: _soft, borderRadius: pw.BorderRadius.circular(7)),
        child: pw.Row(children: [
          pw.Container(width: 68, padding: const pw.EdgeInsets.symmetric(vertical: 6), alignment: pw.Alignment.center, decoration: pw.BoxDecoration(color: color, borderRadius: pw.BorderRadius.circular(5)), child: pw.Text(title, style: pw.TextStyle(font: semi, fontSize: 6.5, color: PdfColors.white))),
          pw.SizedBox(width: 9),
          pw.Expanded(child: pw.Text(codes.isEmpty ? tx('Yok') : codes.join('  •  '), style: pw.TextStyle(font: regular, fontSize: 8, color: codes.isEmpty ? _muted : _dark))),
        ]),
      );

  static int _healthScore(ObdProvider obd, ObdData data) {
    var score = 100;
    score -= obd.dtcEntries.where((e) => e.status == DtcStatus.stored).length * 12;
    score -= obd.dtcEntries.where((e) => e.status == DtcStatus.pending).length * 5;
    if (obd.milOn == true) score -= 12;
    score -= obd.healthWarnings.length * 6;
    final v = obd.controlModuleVoltage ?? data.voltage;
    if (data.rpm > 500 && v > 0 && (v < 13.0 || v > 15.2)) score -= 8;
    if (data.engineTemp > 110) score -= 12;
    return score.clamp(0, 100).toInt();
  }

  static String _healthLabel(int score, List<String> warnings) {
    if (score >= 90 && warnings.isEmpty) return tx('Elektronik teşhis görünümü iyi');
    if (score >= 75) return tx('Küçük kontroller öneriliyor');
    if (score >= 55) return tx('Teşhis bulgularını kontrol et');
    return tx('Öncelikli kontrol gerekli');
  }

  static String _bar(double? value) => value == null ? '-' : '${value.toStringAsFixed(2)} bar';
  static String _percent(double? value) => value == null ? '-' : '${value.toStringAsFixed(1)} %';
  static String _formatDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  static String _filename(Vehicle vehicle, DateTime now, String ext) {
    final plate = vehicle.plate.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final stamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    return 'OTOSINYAL_${plate.isEmpty ? tx('ARAC') : plate}_$stamp.$ext';
  }
}
