import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/vag_long_coding.dart';
import 'package:otosinyal_obd2/l10n/tx.dart';

class VagLongCodingService {
  static const modules = <VagLongCodingModule>[
    VagLongCodingModule(module:'09',name:tx('09 • Merkezi Elektrik / BCM'),requestId:'70E',responseId:'778',writeAllowed:true),
    VagLongCodingModule(module:'17',name:tx('17 • Gösterge Paneli'),requestId:'714',responseId:'77E',writeAllowed:true),
    VagLongCodingModule(module:'19',name:'19 • CAN Gateway',requestId:'710',responseId:'77A',writeAllowed:false),
    VagLongCodingModule(module:'5F',name:tx('5F • Bilgi Elektroniği'),requestId:'773',responseId:'7DD',writeAllowed:true),
    VagLongCodingModule(module:'44',name:tx('44 • Direksiyon Yardımı'),requestId:'712',responseId:'77C',writeAllowed:false,safetyCritical:true),
    VagLongCodingModule(module:'03',name:'03 • ABS / ESP',requestId:'713',responseId:'77D',writeAllowed:false,safetyCritical:true),
    VagLongCodingModule(module:'15',name:'15 • Airbag',requestId:'715',responseId:'77F',writeAllowed:false,safetyCritical:true),
    VagLongCodingModule(module:'01',name:'01 • Motor ECU',requestId:'7E0',responseId:'7E8',writeAllowed:false,safetyCritical:true),
    VagLongCodingModule(module:'02',name:tx('02 • Şanzıman'),requestId:'7E1',responseId:'7E9',writeAllowed:false,safetyCritical:true),
    VagLongCodingModule(module:'A5',name:tx('A5 • Ön Kamera / Sürücü Asistanı'),requestId:'74F',responseId:'7B9',writeAllowed:false,safetyCritical:true),
  ];

  static Future<List<String>> backupCommands(String platform, String module) async {
    final raw = await rootBundle.loadString('assets/data/vag_recovered/vag_backup_catalog_v1.json');
    final root = jsonDecode(raw) as Map<String,dynamic>;
    final p = platform.toUpperCase();
    final m = module.toUpperCase();
    for (final item in (root['entries'] as List? ?? const [])) {
      if (item is! Map) continue;
      final row = Map<String,dynamic>.from(item);
      if ('${row['platform']}'.toUpperCase()==p && '${row['module']}'.toUpperCase()==m) {
        return (row['commands'] as List? ?? const []).map((e)=>'$e').toList(growable:false);
      }
    }
    return const [];
  }

  static List<int>? parseHex(String raw) {
    final h=raw.replaceAll(RegExp(r'[^0-9A-Fa-f]'),'').toUpperCase();
    if(h.isEmpty||h.length.isOdd)return null;
    final out=<int>[];
    for(var i=0;i<h.length;i+=2) out.add(int.parse(h.substring(i,i+2),radix:16));
    return out;
  }

  static String hex(List<int> bytes)=>bytes.map((b)=>(b&0xFF).toRadixString(16).padLeft(2,'0').toUpperCase()).join();
}
