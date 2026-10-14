import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../providers/obd_provider.dart';
import 'package:otosinyal_obd2/l10n/tx.dart';

class LiveSignalDiscoveryScreen extends StatelessWidget {
  const LiveSignalDiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final obd = context.watch<ObdProvider>();
    final signals = obd.discoveredSignals;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background, foregroundColor: Colors.white, title: Text(tx('CANLI VERİ KEŞFİ'), style: TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 28), children: [
        _InfoCard(obd: obd),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: !obd.canQueryDtc || obd.liveSignalDiscoveryBusy ? null : () => context.read<ObdProvider>().discoverLiveSignals(),
          icon: obd.liveSignalDiscoveryBusy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.radar_rounded),
          label: Text(obd.liveSignalDiscoveryBusy ? 'PID / DID TARANIYOR...' : tx('ÇALIŞAN PID / DID’LERİ BUL'), style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
        if (signals.isNotEmpty) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: obd.liveSignalDiscoveryBusy ? null : () => context.read<ObdProvider>().refreshDiscoveredSignals(),
            icon: const Icon(Icons.refresh_rounded), label: Text(tx('DEĞERLERİ YENİLE')),
          ),
        ],
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _Stat(label: tx('ÇALIŞAN'), value: '${signals.length}', color: AppColors.success)),
          const SizedBox(width: 8),
          Expanded(child: _Stat(label: 'GENERIC PID', value: '${signals.where((e) => e.source.contains('Mode 01')).length}', color: AppColors.info)),
          const SizedBox(width: 8),
          Expanded(child: _Stat(label: 'UDS DID', value: '${signals.where((e) => e.source.contains('UDS')).length}', color: AppColors.accentBright)),
        ]),
        const SizedBox(height: 16),
        if (signals.isEmpty)
          const _Empty()
        else
          ...signals.map((s) => Container(
            margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
            child: Row(children: [
              Container(width: 42, height: 42, decoration: BoxDecoration(color: AppColors.info.withValues(alpha: .1), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.sensors_rounded, color: AppColors.info)),
              const SizedBox(width: 11),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                const SizedBox(height: 4), Text('${s.source} • ${s.id}', style: const TextStyle(color: AppColors.textMuted, fontSize: 9.5)),
              ])),
              Text(s.displayValue, textAlign: TextAlign.right, style: const TextStyle(color: AppColors.success, fontSize: 14, fontWeight: FontWeight.w900)),
            ]),
          )),
      ]),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.obd}); final ObdProvider obd;
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF241113), Color(0xFF101113)]), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.accentBorder)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Icon(Icons.auto_awesome_rounded, color: AppColors.accentBright), SizedBox(width: 8), Text(tx('ECU NEYİ GERÇEKTEN VERİYOR?'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))]),
    const SizedBox(height: 7), Text(tx('SAE PID bitmap’lerini cevap veren ECU’lardan birleştirir ve bulunan PID’leri tek tek gerçek cevapla doğrular. Bilinen sensörleri çevirir; ECU’nun cevapladığı bilinmeyen PID’leri ham HEX olarak da gösterir. VAG DID yalnız olumlu 0x62 cevabında listelenir.'), style: TextStyle(color: Colors.white60, fontSize: 10.5, height: 1.45)),
    const SizedBox(height: 9), Text('${obd.detectedBrand ?? tx('Araç')} • ${obd.protocolName ?? obd.adapterInfo.protocol}', style: const TextStyle(color: AppColors.info, fontSize: 10, fontWeight: FontWeight.w800)),
  ]));
}
class _Stat extends StatelessWidget { const _Stat({required this.label, required this.value, required this.color}); final String label,value; final Color color; @override Widget build(BuildContext context)=>Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: color.withValues(alpha:.07), borderRadius: BorderRadius.circular(13), border: Border.all(color: color.withValues(alpha:.22))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[Text(label,style:const TextStyle(color:Colors.white38,fontSize:7,fontWeight:FontWeight.w900)),const SizedBox(height:3),Text(value,style:TextStyle(color:color,fontSize:17,fontWeight:FontWeight.w900))])); }
class _Empty extends StatelessWidget { const _Empty(); @override Widget build(BuildContext context)=>Container(padding: const EdgeInsets.all(28), decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(18)), child: Column(children:[Icon(Icons.sensors_off_rounded,color:Colors.white24,size:38),SizedBox(height:10),Text(tx('Henüz keşif yapılmadı'),style:TextStyle(color:Colors.white,fontWeight:FontWeight.w800)),SizedBox(height:5),Text(tx('Bağlan ve çalışan sensörleri otomatik keşfet.'),style:TextStyle(color:AppColors.textMuted,fontSize:10.5))])); }
