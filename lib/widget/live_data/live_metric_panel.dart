import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_colors.dart';
import '../../providers/obd_provider.dart';
import '../../screens/live_pid_chart_screen.dart';
import 'package:otosinyal_obd2/l10n/tx.dart';

class LiveMetricPanel extends StatefulWidget {
  const LiveMetricPanel({super.key, required this.obd});
  final ObdProvider obd;
  @override State<LiveMetricPanel> createState() => _LiveMetricPanelState();
}

class _LiveMetricPanelState extends State<LiveMetricPanel> {
  static const _key = 'live_metric_order_v2';
  static const _hideKey = 'live_metric_hide_unsupported_v2';
  List<String> _order = const ['voltage','boostTarget','boost','egr','egrError','fuelRail','fuelRate','oilTemp','maf','torque','catalyst'];
  bool _hideUnsupported = true;

  @override void initState(){super.initState();_load();}
  Future<void> _load() async { final p=await SharedPreferences.getInstance(); if(!mounted)return; final saved=p.getStringList(_key); setState((){if(saved!=null&&saved.isNotEmpty)_order=saved;_hideUnsupported=p.getBool(_hideKey)??true;}); }
  Future<void> _save() async { final p=await SharedPreferences.getInstance(); await p.setStringList(_key,_order); await p.setBool(_hideKey,_hideUnsupported); }

  List<_Metric> _metrics(ObdProvider obd) => [
    _Metric('voltage',Icons.battery_charging_full_rounded,tx('AKÜ / ŞARJ'),()=>obd.controlModuleVoltage ?? obd.data.voltage,'V',true,LivePidMetric.voltage,alert:obd.batteryAlert),
    _Metric('boostTarget',Icons.track_changes_rounded,tx('TURBO HEDEF'),()=>obd.commandedBoostGaugeBar,'bar',obd.supportsCommandedBoost,LivePidMetric.boost),
    _Metric('boost',Icons.compress_rounded,tx('TURBO GERÇEK'),()=>obd.actualBoostGaugeBarPid70 ?? obd.boostGaugeBar,'bar',obd.supportsActualBoostPid70 || obd.boostGaugeBar!=null,LivePidMetric.boost),
    _Metric('egr',Icons.air_rounded,tx('EGR KOMUTU'),()=>obd.egrCommandedPercent,'%',obd.supportsEgrData,LivePidMetric.egr),
    _Metric('egrError',Icons.compare_arrows_rounded,tx('EGR SAPMASI'),()=>obd.egrErrorPercent,'%',obd.supportsEgrData,LivePidMetric.egrError,alert:obd.egrErrorPercent!=null&&obd.egrErrorPercent!.abs()>35),
    _Metric('fuelRail',Icons.oil_barrel_outlined,tx('YAKIT RAYI'),()=>obd.fuelRailPressureKpa==null?null:obd.fuelRailPressureKpa!/1000.0,'MPa',obd.supportsFuelRailPressure,LivePidMetric.fuelRail),
    _Metric('fuelRate',Icons.local_gas_station_rounded,tx('YAKIT DEBİSİ'),()=>obd.fuelRateLph,'L/h',obd.supportsFuelRate,LivePidMetric.fuelRate),
    _Metric('oilTemp',Icons.oil_barrel_rounded,tx('YAĞ SICAKLIĞI'),()=>obd.oilTempC?.toDouble(),'°C',obd.supportsOilTemperature,LivePidMetric.oilTemp),
    _Metric('maf',Icons.air_rounded,tx('MAF HAVA AKIŞI'),()=>obd.mafGps,'g/s',obd.supportsMaf,LivePidMetric.maf),
    _Metric('torque',Icons.bolt_rounded,tx('MOTOR TORKU'),()=>obd.actualTorquePercent?.toDouble(),'%',obd.supportsTorqueData,LivePidMetric.torque),
    _Metric('catalyst',Icons.thermostat_rounded,tx('KATALİZÖR SIC.'),()=>obd.catalystTempC,'°C',obd.supportsCatalystTemperature,LivePidMetric.catalyst),
  ];

  @override Widget build(BuildContext context){
    final all=_metrics(widget.obd);
    final byId={for(final m in all)m.id:m};
    final ordered=[..._order.where(byId.containsKey).map((id)=>byId[id]!),...all.where((m)=>!_order.contains(m.id))];
    final visible=_hideUnsupported?ordered.where((m)=>m.supported||m.value()!=null).toList():ordered;
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[
        Expanded(child:Text(tx('CANLI ANALİZ'),style:TextStyle(color:AppColors.info,fontSize:11,fontWeight:FontWeight.w900,letterSpacing:.8))),
        TextButton.icon(onPressed:()=>_openEditor(context,all),icon:const Icon(Icons.tune_rounded,size:16),label:Text(tx('DÜZENLE')),style:TextButton.styleFrom(foregroundColor:Colors.white54,textStyle:const TextStyle(fontSize:9,fontWeight:FontWeight.w900))),
      ]),
      if(visible.isEmpty) Container(width:double.infinity,padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:Theme.of(context).colorScheme.surfaceContainer,borderRadius:BorderRadius.circular(16),border:Border.all(color:Colors.white10)),child:Text(tx('Araçtan desteklenen ek canlı kanal bulunamadı. “Düzenle” içinden desteklenmeyenleri istersen görünür yapabilirsin.'),style:TextStyle(color:Colors.white54,fontSize:11,height:1.4))),
      if(visible.isNotEmpty) GridView.count(crossAxisCount:2,shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),mainAxisSpacing:8,crossAxisSpacing:8,childAspectRatio:1.72,children:visible.map((m)=>_MetricTile(metric:m)).toList()),
    ]);
  }

  Future<void> _openEditor(BuildContext context,List<_Metric> all) async {
    final byId={for(final m in all)m.id:m};
    var temp=[..._order.where(byId.containsKey),...all.map((e)=>e.id).where((id)=>!_order.contains(id))];
    var hide=_hideUnsupported;
    await showModalBottomSheet<void>(context:context,isScrollControlled:true,backgroundColor:const Color(0xFF111215),shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(26))),builder:(ctx)=>StatefulBuilder(builder:(ctx,setModal)=>SizedBox(height:MediaQuery.of(ctx).size.height*.78,child:Padding(padding:const EdgeInsets.fromLTRB(18,14,18,18),child:Column(children:[
      Container(width:42,height:4,decoration:BoxDecoration(color:Colors.white24,borderRadius:BorderRadius.circular(4))),const SizedBox(height:14),
      Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(tx('Canlı veri kartları'),style:TextStyle(color:Colors.white,fontSize:18,fontWeight:FontWeight.w900)),SizedBox(height:3),Text(tx('Sürükleyerek sıralamayı değiştir'),style:TextStyle(color:Colors.white38,fontSize:10))])),Switch(value:hide,onChanged:(v)=>setModal(()=>hide=v),activeColor:AppColors.info)]),
      Row(children:[const Icon(Icons.visibility_off_rounded,size:15,color:Colors.white38),const SizedBox(width:7),Expanded(child:Text(hide?tx('Desteklenmeyenler gizli'):tx('Desteklenmeyenler görünür'),style:const TextStyle(color:Colors.white54,fontSize:10)))]),const SizedBox(height:10),
      Expanded(child:ReorderableListView.builder(itemCount:temp.length,onReorder:(oldIndex,newIndex){setModal((){if(newIndex>oldIndex)newIndex--;final item=temp.removeAt(oldIndex);temp.insert(newIndex,item);});},itemBuilder:(ctx,index){final m=byId[temp[index]]!;return Container(key:ValueKey(m.id),margin:const EdgeInsets.only(bottom:7),padding:const EdgeInsets.symmetric(horizontal:12,vertical:10),decoration:BoxDecoration(color:const Color(0xFF191A1E),borderRadius:BorderRadius.circular(14),border:Border.all(color:m.supported?AppColors.info.withValues(alpha:.22):Colors.white10)),child:Row(children:[Icon(m.icon,color:m.supported?AppColors.info:Colors.white30,size:19),const SizedBox(width:10),Expanded(child:Text(m.title,style:TextStyle(color:m.supported?Colors.white:Colors.white38,fontWeight:FontWeight.w800,fontSize:11))),const Icon(Icons.drag_handle_rounded,color:Colors.white30)]));})),
      SizedBox(width:double.infinity,child:ElevatedButton(onPressed:(){setState((){_order=temp;_hideUnsupported=hide;});_save();Navigator.pop(ctx);},style:ElevatedButton.styleFrom(backgroundColor:AppColors.info,foregroundColor:Colors.white,padding:const EdgeInsets.symmetric(vertical:14),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14))),child:Text(tx('KAYDET'),style:TextStyle(fontWeight:FontWeight.w900))))
    ])))));
  }
}

class _Metric {
  const _Metric(this.id,this.icon,this.title,this.value,this.unit,this.supported,this.chart,{this.alert=false});
  final String id,title,unit; final IconData icon; final double? Function() value; final bool supported,alert; final LivePidMetric chart;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric});
  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    final v = metric.value();
    final supported = metric.supported || v != null;
    final color = metric.alert
        ? AppColors.danger
        : supported
            ? AppColors.info
            : AppColors.unsupported;
    final digits = metric.unit == 'bar' || metric.unit == 'L/h' || metric.unit == 'g/s' || metric.unit == 'V' ? 1 : 0;

    return InkWell(
      onTap: supported
          ? () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LivePidChartScreen(
                    metric: metric.chart,
                    title: metric.title,
                    unit: metric.unit,
                  ),
                ),
              )
          : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: metric.alert ? .5 : .24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(metric.icon, color: color, size: 16),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    metric.title,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (supported)
                  const Icon(Icons.show_chart_rounded, color: Colors.white24, size: 14),
              ],
            ),
            const Spacer(),
            Text(
              v == null ? '--' : '${v.toStringAsFixed(digits)} ${metric.unit}',
              style: TextStyle(
                color: supported ? Colors.white : Colors.white30,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              metric.alert
                  ? tx('Dikkat gerektiren değer')
                  : supported
                      ? tx('Canlı ECU verisi • Grafik için dokun')
                      : 'Desteklenmiyor',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: metric.alert
                    ? AppColors.danger
                    : supported
                        ? Colors.white38
                        : AppColors.unsupported,
                fontSize: 7.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
