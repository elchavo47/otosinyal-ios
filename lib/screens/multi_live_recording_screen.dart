import '../services/ios_share_origin.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../core/app_colors.dart';
import '../providers/obd_provider.dart';
import 'package:otosinyal_obd2/l10n/tx.dart';

class MultiLiveRecordingScreen extends StatefulWidget {
  const MultiLiveRecordingScreen({super.key});
  @override State<MultiLiveRecordingScreen> createState()=>_MultiLiveRecordingScreenState();
}

class _Sample { final DateTime t; final Map<String,double?> v; const _Sample(this.t,this.v); }
class _Metric { final String key,label,unit; final double? Function(ObdProvider) read; const _Metric(this.key,this.label,this.unit,this.read); }

class _MultiLiveRecordingScreenState extends State<MultiLiveRecordingScreen> {
  static final metrics=< _Metric>[
    _Metric('rpm','RPM','rpm',(o)=>o.data.rpm.toDouble()),
    _Metric('boost','Boost','bar',(o)=>o.actualBoostGaugeBarPid70??o.boostGaugeBar),
    _Metric('rail','Rail','bar',(o)=>o.fuelRailPressureKpa==null?null:o.fuelRailPressureKpa!/100.0),
    _Metric('maf','MAF','g/s',(o)=>o.mafGps),
    _Metric('egt','EGT','°C',(o)=>o.catalystTempC),
    _Metric('oil',tx('Yağ'),'°C',(o)=>o.oilTempC?.toDouble()),
    _Metric('coolant',tx('Su'),'°C',(o)=>o.data.engineTemp.toDouble()),
    _Metric('voltage',tx('Voltaj'),'V',(o)=>o.controlModuleVoltage??o.data.voltage),
  ];
  final List<_Sample> samples=[];
  final Set<String> selected={'rpm','boost','rail'};
  Timer? timer; bool recording=false;
  @override void dispose(){timer?.cancel();super.dispose();}
  void toggle(){if(recording){timer?.cancel();setState(()=>recording=false);return;}setState(()=>recording=true);_take();timer=Timer.periodic(const Duration(milliseconds:500),(_)=>_take());}
  void _take(){if(!mounted)return;final o=context.read<ObdProvider>();final map=<String,double?>{};for(final m in metrics)map[m.key]=m.read(o);setState((){samples.add(_Sample(DateTime.now(),map));if(samples.length>3600)samples.removeAt(0);});}
  Future<void> exportCsv() async {if(samples.isEmpty)return;final b=StringBuffer('time,${metrics.map((m)=>m.key).join(',')}\n');for(final s in samples){b.write('${s.t.toIso8601String()},');b.writeln(metrics.map((m)=>s.v[m.key]?.toStringAsFixed(3)??'').join(','));}final dir=await getTemporaryDirectory();final f=File('${dir.path}/otosinyal_live_${DateTime.now().millisecondsSinceEpoch}.csv');await f.writeAsString(b.toString());if(!mounted)return;await Share.shareXFiles([XFile(f.path)],text:tx('OtoSinyal canlı veri kaydı'), sharePositionOrigin: otoShareOrigin());}
  @override Widget build(BuildContext context){final visible=samples.length>240?samples.sublist(samples.length-240):samples;return Scaffold(backgroundColor:AppColors.background,appBar:AppBar(backgroundColor:AppColors.background,foregroundColor:Colors.white,title:const Text('GRAFİK + KAYIT',style:TextStyle(fontWeight:FontWeight.w900)),actions:[IconButton(onPressed:samples.isEmpty?null:exportCsv,tooltip:'CSV dışa aktar',icon:const Icon(Icons.file_download_outlined))]),body:ListView(padding:const EdgeInsets.fromLTRB(16,8,16,28),children:[
    Container(padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:AppColors.cardBg,borderRadius:BorderRadius.circular(18),border:Border.all(color:recording?AppColors.danger.withValues(alpha:.45):Colors.white10)),child:Row(children:[Container(width:46,height:46,decoration:BoxDecoration(color:(recording?AppColors.danger:AppColors.info).withValues(alpha:.1),borderRadius:BorderRadius.circular(14)),child:Icon(recording?Icons.fiber_manual_record_rounded:Icons.multiline_chart_rounded,color:recording?AppColors.danger:AppColors.info)),const SizedBox(width:11),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(recording?tx('KAYIT DEVAM EDİYOR'):tx('ÇOKLU CANLI VERİ'),style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w900)),const SizedBox(height:4),Text(tx('{0} örnek • 500 ms örnekleme • CSV export', [samples.length]),style:const TextStyle(color:Colors.white38,fontSize:9.5))])),ElevatedButton(onPressed:toggle,style:ElevatedButton.styleFrom(backgroundColor:recording?AppColors.danger:AppColors.accent),child:Text(recording?tx('DURDUR'):tx('BAŞLAT')))])),
    const SizedBox(height:12),Wrap(spacing:7,runSpacing:7,children:metrics.map((m)=>FilterChip(selected:selected.contains(m.key),label:Text(m.label),onSelected:(v)=>setState((){if(v){if(selected.length<4)selected.add(m.key);}else if(selected.length>1){selected.remove(m.key);}}))).toList()),
    const SizedBox(height:12),Container(height:280,padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:const Color(0xFF0E0F11),borderRadius:BorderRadius.circular(19),border:Border.all(color:Colors.white10)),child:visible.length<2?Center(child:Text(tx('Kayıt başlatınca grafik burada akacak.'),style:TextStyle(color:Colors.white38))):CustomPaint(painter:_MultiPainter(visible,selected.toList()))),
    const SizedBox(height:10),...selected.map((key){final m=metrics.firstWhere((e)=>e.key==key);final val=samples.isEmpty?null:samples.last.v[key];return Container(margin:const EdgeInsets.only(bottom:7),padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:AppColors.cardBg,borderRadius:BorderRadius.circular(14)),child:Row(children:[Expanded(child:Text(m.label,style:const TextStyle(color:Colors.white70,fontWeight:FontWeight.w700))),Text(val==null?'—':'${val.toStringAsFixed(val.abs()>100?0:1)} ${m.unit}',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w900,fontSize:15))]));}),
    OutlinedButton.icon(onPressed:samples.isEmpty?null:exportCsv,icon:const Icon(Icons.table_view_rounded),label:Text(tx('CSV OLARAK PAYLAŞ'))),
  ]));}
}

class _MultiPainter extends CustomPainter { final List<_Sample> samples; final List<String> keys; const _MultiPainter(this.samples,this.keys); static const colors=[Color(0xFF00D1FF),Color(0xFFFF4D67),Color(0xFFFFB84D),Color(0xFF68E090)]; @override void paint(Canvas c,Size s){final grid=Paint()..color=Colors.white.withValues(alpha:.06)..strokeWidth=1;for(var i=1;i<5;i++)c.drawLine(Offset(0,s.height*i/5),Offset(s.width,s.height*i/5),grid);for(var k=0;k<keys.length;k++){final vals=samples.map((x)=>x.v[keys[k]]).whereType<double>().where((v)=>v.isFinite).toList();if(vals.length<2)continue;var minV=vals.reduce(math.min),maxV=vals.reduce(math.max);if((maxV-minV).abs()<.001){minV-=1;maxV+=1;}final p=Path();var started=false;for(var i=0;i<samples.length;i++){final v=samples[i].v[keys[k]];if(v==null||!v.isFinite)continue;final x=s.width*i/math.max(1,samples.length-1);final y=s.height-((v-minV)/(maxV-minV))*s.height;if(!started){p.moveTo(x,y);started=true;}else{p.lineTo(x,y);}}c.drawPath(p,Paint()..style=PaintingStyle.stroke..strokeWidth=2.2..strokeCap=StrokeCap.round..color=colors[k%colors.length]);}}
@override bool shouldRepaint(covariant _MultiPainter old)=>true;}
