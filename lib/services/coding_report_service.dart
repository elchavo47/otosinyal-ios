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

class CodingReportService {
  static Future<void> createAndShare({required String vin,required VagVehicleProfile profile,required int year,required Iterable<VagModuleIdentity> modules,required Iterable<CodingFeatureState> states,required Iterable<CodingBackupRecord> history}) async {
    final font=pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Regular.ttf'));
    final bold=pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Bold.ttf'));
    final doc=pw.Document(theme:pw.ThemeData.withFont(base:font,bold:bold));
    final moduleList=modules.toList(),stateList=states.toList(),historyList=history.toList();
    doc.addPage(pw.MultiPage(pageFormat:PdfPageFormat.a4,margin:const pw.EdgeInsets.all(30),build:(_)=>[
      pw.Text('OTOSİNYAL • KODLAMA RAPORU',style:pw.TextStyle(fontSize:19,fontWeight:pw.FontWeight.bold,color:PdfColors.red800)),pw.SizedBox(height:12),
      pw.Text('${profile.brand} ${profile.label} • $year • ${profile.platform}',style:pw.TextStyle(fontWeight:pw.FontWeight.bold)),pw.Text('VIN: $vin'),pw.Text('Rapor: ${DateTime.now().toLocal()}'),pw.Divider(),
      pw.Text('ECU KİMLİKLERİ',style:pw.TextStyle(fontWeight:pw.FontWeight.bold)),...moduleList.map((m)=>pw.Bullet(text:'${m.name}: ${m.responding?'Yanıt verdi':'Yanıt yok'} • Parça ${m.partNumber??'-'} • Yazılım ${m.softwareVersion??'-'} • ASAM ${m.asamDataset??'-'}')),
      pw.SizedBox(height:9),pw.Text('UYUMLULUK / MEVCUT DURUM',style:pw.TextStyle(fontWeight:pw.FontWeight.bold)),...stateList.map((s)=>pw.Bullet(text:'${s.recipeId}: ${s.compatibility.label} • ${s.enabled==null?'-':s.enabled!?'Açık':'Kapalı'} • ${s.detail}')),
      pw.SizedBox(height:9),pw.Text('İŞLEM GEÇMİŞİ',style:pw.TextStyle(fontWeight:pw.FontWeight.bold)),if(historyList.isEmpty)pw.Text('Bu VIN için kodlama işlemi yok.'),...historyList.map((h)=>pw.Bullet(text:'${h.createdAt.toLocal()} • ${h.moduleName} • DID ${h.did} • ${h.status.label} • ${h.originalHex} → ${h.requestedHex??'-'}')),
      pw.SizedBox(height:14),pw.Text('Güvenlik: OTOSİNYAL yazmadan önce mevcut değeri yedekler, yazdıktan sonra ECU’dan tekrar okuyarak doğrular. ABS, airbag, direksiyon ve immobilizer yazmaları kapalıdır.',style:const pw.TextStyle(fontSize:8,color:PdfColors.grey700)),
    ]));
    final dir=await getTemporaryDirectory();final file=File('${dir.path}/OTOSINYAL_KODLAMA_${DateTime.now().millisecondsSinceEpoch}.pdf');await file.writeAsBytes(await doc.save(),flush:true);await Share.shareXFiles([XFile(file.path)],subject:'OTOSİNYAL kodlama raporu', sharePositionOrigin: otoShareOrigin());
  }
}
