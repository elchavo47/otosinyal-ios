import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../models/diagnostic_units.dart';
import '../providers/obd_provider.dart';
import '../providers/wifi_obd_provider.dart';

class UnitScanScreen extends StatefulWidget {
  const UnitScanScreen({super.key});
  @override
  State<UnitScanScreen> createState() => _UnitScanScreenState();
}

class _UnitScanScreenState extends State<UnitScanScreen> {
  final Set<DiagnosticUnit> _selected = {DiagnosticUnit.engine};
  late final TextEditingController _doipHost;
  late final TextEditingController _doipPort;

  @override
  void initState() {
    super.initState();
    final wifi = context.read<WifiObdProvider>();
    _doipHost = TextEditingController(text: wifi.host);
    _doipPort = TextEditingController(text: '13400');
  }

  @override
  void dispose() {
    _doipHost.dispose();
    _doipPort.dispose();
    super.dispose();
  }

  void _toggle(DiagnosticUnit unit) {
    setState(() {
      if (!_selected.add(unit)) _selected.remove(unit);
    });
  }

  void _selectAll() => setState(() => _selected.addAll(DiagnosticUnit.values));
  void _clear() => setState(_selected.clear);

  Future<void> _scan() async {
    if (_selected.isEmpty) return;
    await context.read<ObdProvider>().scanSelectedUnits(_selected);
  }

  Future<void> _scanDoip() async {
    final port = int.tryParse(_doipPort.text.trim());
    if (port == null || port < 1 || port > 65535) return;
    await context.read<ObdProvider>().scanSelectedUnitsViaDoip(
          _selected,
          host: _doipHost.text,
          port: port,
        );
  }

  @override
  Widget build(BuildContext context) {
    final obd = context.watch<ObdProvider>();
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Ünite Tarama Merkezi', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [IconButton(onPressed: _selectAll, tooltip: 'Hepsini seç', icon: const Icon(Icons.select_all_rounded))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
        children: [
          _HeroCard(live: obd.canQueryDtc, demo: obd.isDemoMode),
          const SizedBox(height: 12),
          _ScanModeCard(
            busy: obd.isModuleScanning,
            enabled: obd.canQueryDtc,
            selectedCount: _selected.length,
            onQuick: () async {
              setState(() {
                _selected
                  ..clear()
                  ..addAll(const [DiagnosticUnit.engine, DiagnosticUnit.gateway]);
              });
              await context.read<ObdProvider>().scanSelectedUnits(_selected);
            },
            onFull: () async {
              _selectAll();
              await context.read<ObdProvider>().scanSelectedUnits(_selected);
            },
          ),
          const SizedBox(height: 14),
          Row(children:[const Expanded(child:Text('ECU TOPOLOJİSİ',style:TextStyle(color:Colors.white,fontSize:12,fontWeight:FontWeight.w700))),TextButton.icon(onPressed:_selectAll,icon:const Icon(Icons.select_all_rounded,size:17),label:const Text('Tümünü seç'))]),
          const SizedBox(height: 8),
          _EcuTopologyMap(
            definitions: diagnosticUnitDefinitions,
            selected: _selected,
            results: obd.moduleScanResults,
            onTap: _toggle,
          ),
          const SizedBox(height: 14),
          Row(children:[const Expanded(child:Text('MODÜL DETAYLARI',style:TextStyle(color:AppColors.textMuted,fontSize:10.5,fontWeight:FontWeight.w700))),TextButton(onPressed:_clear,child:const Text('Temizle'))]),
          const SizedBox(height: 6),
          ...diagnosticUnitDefinitions.map((definition) => _UnitTile(definition: definition, selected: _selected.contains(definition.unit), result: obd.moduleScanResults[definition.unit], onTap: () => _toggle(definition.unit))),
          const SizedBox(height: 8),
          _DoipScanCard(host: _doipHost, port: _doipPort, busy: obd.isModuleScanning, enabled: _selected.isNotEmpty, onScan: _scanDoip),
          const SizedBox(height: 12),
          const _NoteCard(text: 'Hızlı Kontrol yalnızca temel ECU erişimini doğrular. Tam ECU Taraması tüm tanımlı üniteleri tek tek sorgular. Airbag ve diğer güvenlik modüllerinde kodlama/aktüatör/security access çalıştırılmaz.'),
        ],
      ),
    );
  }
}

class _ScanModeCard extends StatelessWidget {
  const _ScanModeCard({required this.busy,required this.enabled,required this.selectedCount,required this.onQuick,required this.onFull});
  final bool busy,enabled; final int selectedCount; final VoidCallback onQuick,onFull;
  @override Widget build(BuildContext context)=>Container(
    padding:const EdgeInsets.all(13),
    decoration:BoxDecoration(color:Theme.of(context).colorScheme.surfaceContainer,borderRadius:BorderRadius.circular(18),border:Border.all(color:Colors.white.withValues(alpha:.08))),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('TARAMA MODU',style:TextStyle(color:Colors.white,fontSize:12,fontWeight:FontWeight.w700)),
      const SizedBox(height:4),
      const Text('Hızlı kontrol ve tam tarama artık ayrı. Gereksiz yere bütün ECU’ları taramak zorunda değilsin.',style:TextStyle(color:AppColors.textMuted,fontSize:9.5,height:1.35)),
      const SizedBox(height:10),
      Row(children:[
        Expanded(child:OutlinedButton.icon(onPressed:!enabled||busy?null:onQuick,icon:const Icon(Icons.bolt_rounded),label:const Text('HIZLI KONTROL',style:TextStyle(fontWeight:FontWeight.w700,fontSize:10)))),
        const SizedBox(width:8),
        Expanded(child:FilledButton.icon(onPressed:!enabled||busy?null:onFull,icon:busy?const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.radar_rounded),label:Text(busy?'TARANIYOR...':'TAM ECU TARAMASI',style:const TextStyle(fontWeight:FontWeight.w700,fontSize:10)))),
      ]),
      const SizedBox(height:6),
      Text('$selectedCount modül seçili',style:const TextStyle(color:Colors.white38,fontSize:8.5)),
    ]),
  );
}

class _EcuTopologyMap extends StatelessWidget {
  const _EcuTopologyMap({required this.definitions,required this.selected,required this.results,required this.onTap});
  final List<DiagnosticUnitDefinition> definitions;
  final Set<DiagnosticUnit> selected;
  final Map<DiagnosticUnit,DiagnosticUnitScanResult> results;
  final ValueChanged<DiagnosticUnit> onTap;
  @override Widget build(BuildContext context){
    DiagnosticUnitDefinition? gateway;
    final others=<DiagnosticUnitDefinition>[];
    for(final d in definitions){if(d.unit==DiagnosticUnit.gateway){gateway=d;}else{others.add(d);}}
    return Container(
      height:310,padding:const EdgeInsets.all(12),
      decoration:BoxDecoration(gradient:AppColors.glassGradient,borderRadius:BorderRadius.circular(22),border:Border.all(color:AppColors.info.withValues(alpha:.22))),
      child:LayoutBuilder(builder:(context,c){
        final center=Offset(c.maxWidth/2,c.maxHeight/2);
        final positions=<Offset>[
          const Offset(.18,.22),const Offset(.82,.22),const Offset(.12,.60),const Offset(.88,.60),const Offset(.30,.86),const Offset(.70,.86),
        ];
        return Stack(children:[
          CustomPaint(size:Size.infinite,painter:_TopologyLines(center:center,points:[for(int i=0;i<others.length&&i<positions.length;i++)Offset(c.maxWidth*positions[i].dx,c.maxHeight*positions[i].dy)])),
          if(gateway!=null)Positioned(left:center.dx-46,top:center.dy-39,child:_TopologyNode(definition:gateway,selected:selected.contains(gateway.unit),result:results[gateway.unit],primary:true,onTap:()=>onTap(gateway!.unit))),
          for(int i=0;i<others.length&&i<positions.length;i++)Positioned(left:c.maxWidth*positions[i].dx-40,top:c.maxHeight*positions[i].dy-35,child:_TopologyNode(definition:others[i],selected:selected.contains(others[i].unit),result:results[others[i].unit],onTap:()=>onTap(others[i].unit))),
        ]);
      }),
    );
  }
}

class _TopologyLines extends CustomPainter {
  const _TopologyLines({required this.center,required this.points}); final Offset center; final List<Offset> points;
  @override void paint(Canvas canvas,Size size){final p=Paint()..color=AppColors.info.withValues(alpha:.20)..strokeWidth=1.2;for(final point in points)canvas.drawLine(center,point,p);}
  @override bool shouldRepaint(covariant _TopologyLines oldDelegate)=>false;
}

class _TopologyNode extends StatelessWidget {
  const _TopologyNode({required this.definition,required this.selected,required this.result,required this.onTap,this.primary=false});
  final DiagnosticUnitDefinition definition; final bool selected,primary; final DiagnosticUnitScanResult? result; final VoidCallback onTap;
  @override Widget build(BuildContext context){
    final found=result?.discovered==true;
    final color=found?AppColors.success:result==null?(selected?AppColors.info:AppColors.textMuted):AppColors.warning;
    return GestureDetector(onTap:onTap,child:AnimatedContainer(duration:const Duration(milliseconds:180),width:primary?92:80,padding:EdgeInsets.symmetric(horizontal:6,vertical:primary?11:9),decoration:BoxDecoration(color:const Color(0xFF111316),borderRadius:BorderRadius.circular(primary?18:15),border:Border.all(color:color.withValues(alpha:(selected || found) ? 0.50 : 0.22),width:primary?1.4:1)),child:Column(mainAxisSize:MainAxisSize.min,children:[Icon(definition.icon,color:color,size:primary?24:20),const SizedBox(height:5),Text(definition.label,textAlign:TextAlign.center,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:Colors.white,fontSize:primary?10:9,fontWeight:FontWeight.w700)),const SizedBox(height:2),Text(found?'CANLI':result==null?'BEKLEMEDE':result!.statusLabel,textAlign:TextAlign.center,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:color,fontSize:7,fontWeight:FontWeight.w600))])));
  }
}

class _DoipScanCard extends StatelessWidget {
  const _DoipScanCard({required this.host, required this.port, required this.busy, required this.enabled, required this.onScan});
  final TextEditingController host;
  final TextEditingController port;
  final bool busy;
  final bool enabled;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: AppColors.glassGradient,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.accentCyan.withValues(alpha: .35)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.lan_rounded, color: AppColors.accentCyan, size: 19), SizedBox(width: 8), Text('DoIP / UDS GATEWAY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: .6))]),
          const SizedBox(height: 5),
          const Text('ELM327 Wi‑Fi’den farklı olarak ISO 13400 TCP 13400 kullanır. Tanımlı logical address profilleri üzerinde yalnızca F190 ve 1902FF okunur.', style: TextStyle(color: AppColors.textMuted, fontSize: 10, height: 1.35)),
          const SizedBox(height: 11),
          Row(children: [
            Expanded(child: TextField(controller: host, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'Gateway IP / host', prefixIcon: Icon(Icons.router_rounded)))),
            const SizedBox(width: 8),
            SizedBox(width: 100, child: TextField(controller: port, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Port'))),
          ]),
          const SizedBox(height: 11),
          SizedBox(width: double.infinity, height: 46, child: OutlinedButton.icon(onPressed: busy || !enabled ? null : onScan, icon: busy ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.hub_rounded), label: Text(busy ? 'DoIP TARANIYOR…' : 'DOIP İLE SEÇİLENLERİ TARA'))),
        ]),
      );
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.live, required this.demo});
  final bool live;
  final bool demo;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(17), decoration: BoxDecoration(gradient: AppColors.vipGradient, borderRadius: BorderRadius.circular(23), boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: .3), blurRadius: 25, offset: const Offset(0, 8))]), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.account_tree_rounded, color: Colors.white, size: 33), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Aracın elektronik haritası', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)), const SizedBox(height: 5), Text(demo ? 'Demo verileriyle ekran akışını test ediyorsun.' : live ? 'Gerçek ECU cevapları geldikçe üniteler tek tek doğrulanır.' : Platform.isIOS ? 'Önce Bluetooth veya Wi‑Fi üzerinden OBD’ye bağlan.' : 'Önce Bluetooth, Wi‑Fi veya OTG USB üzerinden OBD’ye bağlan.', style: const TextStyle(color: Colors.white70, fontSize: 10.5, height: 1.4))]))]));
}

class _UnitTile extends StatelessWidget {
  const _UnitTile({required this.definition, required this.selected, required this.result, required this.onTap});
  final DiagnosticUnitDefinition definition;
  final bool selected;
  final DiagnosticUnitScanResult? result;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final found = result?.discovered == true;
    final resultColor = result == null ? AppColors.textMuted : found ? AppColors.success : result!.demo ? AppColors.warning : AppColors.textMuted;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(gradient: selected ? AppColors.glassGradient : null, color: selected ? null : Colors.white.withValues(alpha: .025), borderRadius: BorderRadius.circular(18), border: Border.all(color: selected ? AppColors.accent.withValues(alpha: .55) : Colors.white.withValues(alpha: .08))),
        child: Row(children: [
          AnimatedContainer(duration: const Duration(milliseconds: 220), width: 38, height: 38, decoration: BoxDecoration(color: selected ? AppColors.accent.withValues(alpha: .2) : Colors.white.withValues(alpha: .05), borderRadius: BorderRadius.circular(13)), child: Icon(definition.icon, color: selected ? AppColors.accentBright : AppColors.textMuted, size: 20)),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(definition.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)), const SizedBox(height: 3), Text(result?.detail ?? definition.subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 10, height: 1.3)), if (result?.responseId != null) Text('${result!.protocol ?? 'CAN'} cevap ID: ${result!.responseId}', style: TextStyle(color: resultColor, fontSize: 9, fontWeight: FontWeight.w600)), if (result?.profile != null) Text(result!.profile!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.accentCyan, fontSize: 8.5, fontWeight: FontWeight.w700))])),
          if (result != null) Padding(padding: const EdgeInsets.only(right: 7), child: Text(result!.statusLabel, style: TextStyle(color: resultColor, fontSize: 8, fontWeight: FontWeight.w700))),
          Icon(selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: selected ? AppColors.accentBright : AppColors.textMuted, size: 21),
        ]),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: AppColors.info.withValues(alpha: .08), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.info.withValues(alpha: .25))), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.lock_outline_rounded, color: AppColors.info, size: 18), const SizedBox(width: 8), Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 10, height: 1.45)))]));
}
