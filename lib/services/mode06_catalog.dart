import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class Mode06Catalog {
  static Map<int,String> _mids={};
  static Map<int,String> _tids={};
  static bool _loaded=false;
  static Future<void> initialize() async {
    if(_loaded) return;
    try {
      final a=jsonDecode(await rootBundle.loadString('assets/data/delphi/mode06-obdmids.json')) as Map<String,dynamic>;
      final b=jsonDecode(await rootBundle.loadString('assets/data/delphi/mode06-tids.json')) as Map<String,dynamic>;
      int hx(dynamic v)=>int.parse(v.toString().replaceFirst('0x',''),radix:16);
      _mids={for(final e in ((a['entries'] as List?)??const[]).whereType<Map>()) hx(e['obdmid']):'${e['name'] ?? ''}'};
      _tids={for(final e in ((b['entries'] as List?)??const[]).whereType<Map>()) hx(e['tid']):'${e['name'] ?? ''}'};
    } catch (_) {} finally {_loaded=true;}
  }
  static String midName(int id)=>_mids[id] ?? 'Monitor 0x${id.toRadixString(16).padLeft(2,'0').toUpperCase()}';
  static String tidName(int id)=>_tids[id] ?? 'Test 0x${id.toRadixString(16).padLeft(2,'0').toUpperCase()}';
}
