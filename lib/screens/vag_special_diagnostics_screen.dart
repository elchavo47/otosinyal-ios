import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../providers/obd_provider.dart';
import '../models/discovered_signal.dart';
import 'vag_dpf_service_regen_screen.dart';
import 'package:otosinyal_obd2/l10n/tx.dart';

class VagSpecialDiagnosticsScreen extends StatelessWidget {
  const VagSpecialDiagnosticsScreen({super.key});
  @override Widget build(BuildContext context) {
    final obd=context.watch<ObdProvider>();
    final sig=obd.discoveredSignals.where((e)=>e.source.contains('VAG UDS')).toList();
    List<DiscoveredSignal> find(String word)=>sig.where((e)=>e.name.toLowerCase().contains(word)).toList();
    final turbo=sig.where((e)=>e.name.toLowerCase().contains('turbo')).toList();
    final dpf=sig.where((e)=>e.name.toLowerCase().contains('dpf')).toList();
    final misfire=sig.where((e)=>e.name.toLowerCase().contains('misfire')).toList();
    final rail=find('rail');
    return Scaffold(backgroundColor:AppColors.background,appBar:AppBar(backgroundColor:AppColors.background,foregroundColor:Colors.white,title:const Text('VAG MOTOR LAB',style:TextStyle(fontWeight:FontWeight.w900))),body:ListView(padding:const EdgeInsets.fromLTRB(16,8,16,28),children:[
      Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF2A0D10),Color(0xFF101113)]),borderRadius:BorderRadius.circular(20),border:Border.all(color:AppColors.accentBorder)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('DPF • TURBO • RAIL • MISFIRE',style:TextStyle(color:Colors.white,fontSize:17,fontWeight:FontWeight.w900)),SizedBox(height:6),Text(tx('Sadece ECU’nun olumlu cevap verdiği VAG UDS verileri gösterilir. Desteklenmeyen DID yerine sahte değer basılmaz.'),style:TextStyle(color:Colors.white60,fontSize:10.5,height:1.4))])),
      const SizedBox(height:12),ElevatedButton.icon(onPressed:!obd.canQueryDtc||obd.liveSignalDiscoveryBusy?null:()=>context.read<ObdProvider>().discoverLiveSignals(),icon:obd.liveSignalDiscoveryBusy?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.radar_rounded),label:Text(sig.isEmpty?tx('VAG CANLI VERİLERİ KEŞFET'):tx('YENİDEN KEŞFET'),style:const TextStyle(fontWeight:FontWeight.w900))),
      if(sig.isNotEmpty)...[const SizedBox(height:8),OutlinedButton.icon(onPressed:obd.liveSignalDiscoveryBusy?null:()=>context.read<ObdProvider>().refreshDiscoveredSignals(),icon:const Icon(Icons.refresh_rounded),label:Text(tx('CANLI DEĞERLERİ YENİLE')))],
      // DPF servis rejenerasyonu ECU'ya yazar; yalnız kodlamaya uygun bağlantıda gösterilir.
      if(obd.codingTabAvailable)...[const SizedBox(height:14),
      Container(
        decoration:BoxDecoration(color:Colors.orange.withValues(alpha:.08),borderRadius:BorderRadius.circular(15),border:Border.all(color:Colors.orange.withValues(alpha:.32))),
        child:ListTile(
          onTap:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>const VagDpfServiceRegenScreen())),
          leading:const Icon(Icons.local_fire_department_rounded,color:Colors.orange),
          title:Text(tx('DPF SERVİS REJENERASYONU'),style:TextStyle(fontSize:11,fontWeight:FontWeight.w900)),
          subtitle:Text(tx('Recovery DB doğrulamalı VAG servis rejenerasyonu • Motor ECU 7E0/7E8 • DID 0316'),style:TextStyle(fontSize:8.5,color:Colors.white60)),
          trailing:const Icon(Icons.chevron_right_rounded,color:Colors.orange),
        ),
      )],
      const SizedBox(height:16),
      _Group(title:'TURBO',icon:Icons.speed_rounded,signals:turbo,extra:[_virtual(tx('Generic gerçek boost'),obd.actualBoostGaugeBarPid70??obd.boostGaugeBar,'bar'),_virtual(tx('Generic hedef boost'),obd.commandedBoostGaugeBar,'bar')]),
      _Group(title:tx('YAKIT RAIL'),icon:Icons.water_drop_rounded,signals:rail,extra:[_virtual(tx('SAE rail basıncı'),obd.fuelRailPressureKpa==null?null:obd.fuelRailPressureKpa!/100.0,'bar')]),
      _Group(title:'DPF / EGT',icon:Icons.filter_alt_rounded,signals:dpf,extra:[_virtual(tx('Katalizör / EGT generic'),obd.catalystTempC,'°C')]),
      _Group(title:'MISFIRE',icon:Icons.bolt_rounded,signals:misfire),
      if(sig.isEmpty)Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(color:AppColors.cardBg,borderRadius:BorderRadius.circular(17)),child:Text(obd.isVagVehicle?tx('Keşif sonrası ECU’nun gerçekten desteklediği özel veriler burada açılacak.'):tx('Bu panel VAG (VW/Audi/Skoda/Seat/Cupra/Porsche) motor ECU’ları içindir.'),textAlign:TextAlign.center,style:const TextStyle(color:Colors.white54,fontSize:11,height:1.45))),
    ]));
  }
  static DiscoveredSignal? _virtual(String name,double? value,String unit)=>value==null?null:DiscoveredSignal(id:'GENERIC',name:name,source:'SAE OBD',unit:unit,numericValue:value,updatedAt:DateTime.now());
}
class _Group extends StatelessWidget {
  const _Group({required this.title, required this.icon, required this.signals, this.extra = const []});
  final String title;
  final IconData icon;
  final List<DiscoveredSignal> signals;
  final List<DiscoveredSignal?> extra;

  @override
  Widget build(BuildContext context) {
    final all = <DiscoveredSignal>[...signals, ...extra.whereType<DiscoveredSignal>()];
    if (all.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: AppColors.info, size: 17),
          const SizedBox(width: 7),
          Text(title, style: const TextStyle(color: AppColors.info, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .8)),
        ]),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: all.map((signal) => Container(
            width: (MediaQuery.of(context).size.width - 40) / 2,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(signal.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 9.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(signal.displayValue, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(signal.id, style: const TextStyle(color: Colors.white24, fontSize: 7.5, fontFamily: 'monospace')),
            ]),
          )).toList(),
        ),
      ]),
    );
  }
}

