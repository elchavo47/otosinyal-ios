import 'ios_share_origin.dart';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../data/vag_vehicle_catalog.dart';
import '../models/coding_backup_record.dart';
import '../models/vag_coding.dart';
import 'package:otosinyal_obd2/l10n/tx.dart';

class CodingReportService {
  static Future<void> createAndShare({required String vin,required VagVehicleProfile profile,required int year,required Iterable<VagModuleIdentity> modules,required Iterable<CodingFeatureState> states,required Iterable<CodingBackupRecord> history}) async {
    final font=pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Regular.ttf'));
    final bold=pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Bold.ttf'));
    final doc=pw.Document(theme:pw.ThemeData.withFont(base:font,bold:bold));
    final moduleList=modules.toList(),stateList=states.toList(),historyList=history.toList();
    doc.addPage(pw.MultiPage(pageFormat:PdfPageFormat.a4,margin:const pw.EdgeInsets.all(30),build:(_)=>[
      pw.Text(tx('OTOSİNYAL • KODLAMA RAPORU'),style:pw.TextStyle(fontSize:19,fontWeight:pw.FontWeight.bold,color:PdfColors.red800)),pw.SizedBox(height:12),
      pw.Text('${profile.brand} ${profile.label} • $year • ${profile.platform}',style:pw.TextStyle(fontWeight:pw.FontWeight.bold)),pw.Text('VIN: $vin'),pw.Text(tx('Rapor: {0}', [DateTime.now().toLocal()])),pw.Divider(),
      pw.Text(tx('ECU KİMLİKLERİ'),style:pw.TextStyle(fontWeight:pw.FontWeight.bold)),...moduleList.map((m)=>pw.Bullet(text:tx('{0}: {1} • Parça {2} • Yazılım {3} • ASAM {4}', [m.name, m.responding?tx('Yanıt verdi'):tx('Yanıt yok'), m.partNumber??'-', m.softwareVersion??'-', m.asamDataset??'-']))),
      pw.SizedBox(height:9),pw.Text(tx('UYUMLULUK / MEVCUT DURUM'),style:pw.TextStyle(fontWeight:pw.FontWeight.bold)),...stateList.map((s)=>pw.Bullet(text:'${s.recipeId}: ${s.compatibility.label} • ${s.enabled==null?'-':s.enabled!?tx('Açık'):tx('Kapalı')} • ${s.detail}')),
      pw.SizedBox(height:9),pw.Text(tx('İŞLEM GEÇMİŞİ'),style:pw.TextStyle(fontWeight:pw.FontWeight.bold)),if(historyList.isEmpty)pw.Text(tx('Bu VIN için kodlama işlemi yok.')),...historyList.map((h)=>pw.Bullet(text:'${h.createdAt.toLocal()} • ${h.moduleName} • DID ${h.did} • ${h.status.label} • ${h.originalHex} → ${h.requestedHex??'-'}')),
      pw.SizedBox(height:14),pw.Text(tx('Güvenlik: OTOSİNYAL yazmadan önce mevcut değeri yedekler, yazdıktan sonra ECU’dan tekrar okuyarak doğrular. ABS, airbag, direksiyon ve immobilizer yazmaları kapalıdır.'),style:const pw.TextStyle(fontSize:8,color:PdfColors.grey700)),
    ]));
    final dir=await getTemporaryDirectory();final file=File(tx('{0}/OTOSINYAL_KODLAMA_{1}.pdf', [dir.path, DateTime.now().millisecondsSinceEpoch]));await file.writeAsBytes(await doc.save(),flush:true);await Share.shareXFiles([XFile(file.path)],subject:tx('OTOSİNYAL kodlama raporu'), sharePositionOrigin: otoShareOrigin());
  }
}
