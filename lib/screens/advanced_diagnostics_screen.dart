import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../providers/obd_provider.dart';
import '../providers/garage_provider.dart';
import '../providers/dtc_history_provider.dart';
import '../providers/maintenance_provider.dart';
import '../services/diagnostic_report_service.dart';
import '../services/oem_vehicle_support.dart';
import 'smart_diagnostic_tools_screen.dart';
import 'unit_scan_screen.dart';
import 'multi_live_recording_screen.dart';
import 'performance_test_screen.dart';
import '../widget/live_data/live_metric_panel.dart';
import 'package:otosinyal_obd2/l10n/tx.dart';

class AdvancedDiagnosticsScreen extends StatelessWidget {
  const AdvancedDiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final obd = context.watch<ObdProvider>();
    final vehicle = context.watch<GarageProvider>().activeVehicle;
    final history = context.watch<DtcHistoryProvider>().forVehicle(vehicle?.id);
    final live = obd.isRealMode || obd.isDemoMode;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF080808),
        elevation: 0,
        title: Text(tx('Canlı Teşhis'), style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            tooltip: tx('Verileri Yenile'),
            onPressed: live ? () => context.read<ObdProvider>().refreshAdvancedDiagnostics() : null,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: !live
          ? const _EmptyState()
          : RefreshIndicator(
              onRefresh: () => context.read<ObdProvider>().refreshAdvancedDiagnostics(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
                children: [
                  if (obd.isDemoMode) ...[
                    const _DemoModeBanner(),
                    const SizedBox(height: 12),
                  ],
                  _HeroStatus(obd: obd, vehicleName: vehicle?.displayName ?? (obd.detectedBrand == null ? tx('VIN ile otomatik tanıma') : tx('{0} • VIN ile algılandı', [obd.detectedBrand]))),
                  const SizedBox(height: 12),
                  _DiagnosticModeCard(obd: obd),
                  const SizedBox(height: 10),
                  _SectionTitle(tx('HIZLI ERİŞİM')),
                  const SizedBox(height: 8),
                  _DiagnosticQuickActions(obd: obd),
                  const SizedBox(height: 10),
                  const SizedBox(height: 14),
                  _SectionTitle(tx('CANLI DURUM')),
                  LiveMetricPanel(obd: obd),
                  const SizedBox(height: 8),
                  _InfoPanel(text: tx('{0} kullanılabilir canlı veri kanalı algılandı. Desteklenmeyen PID’ler varsayılan olarak gizlenir.', [obd.supportedPidCount])),
                  const SizedBox(height: 14),
                  ExpansionTile(
                    initiallyExpanded: false,
                    tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                    childrenPadding: EdgeInsets.zero,
                    title: Text(tx('Gelişmiş araçlar'),style:TextStyle(color:Colors.white,fontWeight:FontWeight.w700,fontSize:12)),
                    subtitle: Text(tx('VIN, OEM detayları, bakım ve Smart Lab'),style:TextStyle(color:Colors.white38,fontSize: 11)),
                    children:[
                      _VinDetectionCard(obd: obd),
                      const SizedBox(height:10),
                      _OemDiagnosticCard(obd: obd),
                      const SizedBox(height:10),
                      const _MaintenanceCard(),
                      const SizedBox(height:10),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ExpansionTile(
                    initiallyExpanded: false,
                    tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                    title: Text(tx('Tüm akıllı araçlar'),
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    subtitle: Text(tx('Ünite tarama, AI mekanik, grafik, VAG ve diğer araçlar'),
                      style: TextStyle(color: Colors.white54, fontSize: 11)),
                    children: const [SmartDiagnosticHub()],
                  ),

                  const SizedBox(height: 14),
                  _SectionTitle(tx('AKILLI UYARILAR')),
                  if (obd.healthWarnings.isEmpty)
                    const _HealthyCard()
                  else
                    ...obd.healthWarnings.map((warning) => _WarningTile(text: warning)),
                  const SizedBox(height: 14),
                  _SectionTitle(tx('ARAÇ VE SİSTEM')),
                  _VehicleOemSupportCard(vehicle: vehicle, obd: obd),
                  const SizedBox(height: 10),
                  _HealthScoreCard(obd: obd),
                  const SizedBox(height: 10),
                  _AdapterQualityCard(obd: obd),
                  const SizedBox(height: 14),
                  _SectionTitle(tx('PERFORMANS')),
                  _PerformanceHeroCard(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PerformanceTestScreen()),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SectionTitle(tx('GEÇMİŞ VE ARAÇLAR')),
                  if (history.isEmpty)
                    _InfoPanel(text: tx('Henüz bu araç için kaydedilmiş DTC taraması yok.'))
                  else
                    ...history.take(5).map((e) => _HistoryTile(
                          date: e.scannedAt,
                          total: e.stored.length + e.pending.length + e.permanent.length,
                          milOn: e.milOn,
                        )),
                  const SizedBox(height: 14),
                  if (vehicle != null)
                    SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await DiagnosticReportService.createAndShare(vehicle: vehicle, obd: obd);
                          } catch (_) {
                            messenger.showSnackBar(SnackBar(content: Text(tx('PDF raporu oluşturulamadı.'))));
                          }
                        },
                        icon: const Icon(Icons.picture_as_pdf_rounded),
                        label: Text(tx('PDF EKSPERTİZ / TEŞHİS RAPORU'), style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}


class _DiagnosticQuickActions extends StatelessWidget {
  const _DiagnosticQuickActions({required this.obd});
  final ObdProvider obd;
  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: _QuickAction(icon: Icons.radar_rounded, label: tx('TAM TARAMA'),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const UnitScanScreen())))),
    const SizedBox(width: 8),
    Expanded(child: _QuickAction(icon: Icons.multiline_chart_rounded,
      label: tx('GRAFİK / KAYIT'), onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const MultiLiveRecordingScreen())))),
    const SizedBox(width: 8),
    Expanded(child: _QuickAction(icon: Icons.tune_rounded, label: tx('ARAÇ ANALİZİ'),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const VehicleAnalyzerScreen())))),
  ]);
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFF1A1D22), borderRadius: BorderRadius.circular(14),
    child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14),
      child: Container(height: 76, padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: AppColors.accentBright, size: 23),
          const SizedBox(height: 7),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 9,
              fontWeight: FontWeight.w800, letterSpacing: .2)),
        ]),
      ),
    ),
  );
}

class _PerformanceHeroCard extends StatelessWidget {
  const _PerformanceHeroCard({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(17),
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF3B1117), Color(0xFF15090B)]),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: AppColors.accentBright.withValues(alpha: .60), width: 1.2),
              boxShadow: [BoxShadow(color: AppColors.accentBright.withValues(alpha: .12), blurRadius: 20, offset: const Offset(0, 7))],
            ),
            child: Row(children: [
              Container(width: 52, height: 52, decoration: BoxDecoration(color: AppColors.accentBright.withValues(alpha: .12), borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.timer_rounded, color: AppColors.accentBright, size: 30)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tx('PERFORMANS TESTİ'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                SizedBox(height: 4),
                Text('0-100 • 60-100 • 80-120 • 100-200', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w800)),
                SizedBox(height: 3),
                Text(tx('Başlangıcı ve hedefi otomatik algılar • sonucu otomatik kaydeder'), style: TextStyle(color: AppColors.accentBright, fontSize: 11, fontWeight: FontWeight.w800)),
              ])),
              const Icon(Icons.chevron_right_rounded, color: Colors.white70),
            ]),
          ),
        ),
      );
}

class _DiagnosticModeCard extends StatelessWidget {
  const _DiagnosticModeCard({required this.obd}); final ObdProvider obd;
  @override Widget build(BuildContext context){
    final busy=obd.isFullScanning||obd.isReadingCodes;
    return Container(
      padding:const EdgeInsets.all(13),
      decoration:BoxDecoration(color:Theme.of(context).colorScheme.surfaceContainer,borderRadius:BorderRadius.circular(16),border:Border.all(color:Colors.white.withValues(alpha:.08))),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(tx('TEŞHİS MODU'),style:TextStyle(color:Colors.white,fontSize:12,fontWeight:FontWeight.w700)),
        const SizedBox(height:4),
        Text(tx('Hızlı Kontrol günlük kullanım içindir. Tam ECU Taraması VIN, DTC, readiness, freeze-frame, Mode 06 ve OEM keşfini birlikte çalıştırır.'),style:TextStyle(color:Colors.white54,fontSize: 11,height:1.35)),
        const SizedBox(height:10),
        Row(children:[
          Expanded(child:OutlinedButton.icon(onPressed:busy?null:()async{final o=context.read<ObdProvider>();await o.readTroubleCodes();await o.readReadiness();await o.refreshAdvancedDiagnostics();},icon:const Icon(Icons.bolt_rounded),label:Text(obd.isReadingCodes?tx('KONTROL...'):tx('HIZLI KONTROL'),style:const TextStyle(fontWeight:FontWeight.w700,fontSize:10)))),
          const SizedBox(width:8),
          Expanded(child:FilledButton.icon(onPressed:busy?null:()=>context.read<ObdProvider>().runFullVehicleScan(),icon:obd.isFullScanning?const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.radar_rounded),label:Text(obd.isFullScanning?'TARANIYOR...':tx('TAM ECU TARAMASI'),style:const TextStyle(fontWeight:FontWeight.w700,fontSize:10)))),
        ]),
      ]),
    );
  }
}

class _DemoModeBanner extends StatelessWidget {
  const _DemoModeBanner();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF23170A),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.amber.withValues(alpha: .45)),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.science_rounded, color: Colors.amber, size: 21),
      SizedBox(width: 9),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tx('DEMO TEŞHİS LABORATUVARI'), style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w700, fontSize: 12)),
        SizedBox(height: 3),
        Text(tx('Araç gerekmeden tam tarama, araç kimliği, arıza kayıtları, arıza anı verileri, emisyon hazırlığı, sistem testleri ve turbo hedef/gerçek ekranlarını test ediyorsun. Bu ekrandaki araç değerleri simülasyondur.'), style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.35)),
      ])),
    ]),
  );
}

class _VehicleOemSupportCard extends StatelessWidget {
  const _VehicleOemSupportCard({required this.vehicle, required this.obd});
  final dynamic vehicle;
  final ObdProvider obd;

  @override
  Widget build(BuildContext context) {
    if (vehicle == null) {
      return _InfoPanel(text: tx('Araç profili VIN üzerinden otomatik oluşturulur. OBD bağlantısı kurulduğunda marka ve desteklenen ECU özellikleri burada doğrulanır.'));
    }
    final eligible = OemVehicleSupport.isEligible(vehicle);
    final group = OemVehicleSupport.groupFor(vehicle.brand);
    final ecuConfirmed = obd.oemDiscovery.identities.any((e) => e.supported) && obd.oemDiscovery.respondingCanIds.isNotEmpty;
    final turboTarget = obd.supportsCommandedBoost && obd.commandedBoostAbsKpa != null;
    final turboActual = (obd.actualBoostGaugeBarPid70 ?? obd.boostGaugeBar) != null;
    final egr = obd.supportsEgrData;
    final rail = obd.supportsFuelRailPressure;
    final dpf = obd.supportsGenericDpfData;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: eligible ? AppColors.accentBorder : Colors.white12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(eligible ? Icons.verified_user_rounded : Icons.directions_car_rounded, color: eligible ? AppColors.accentBright : Colors.white38, size: 22),
          const SizedBox(width: 9),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(vehicle.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 2),
            Text(eligible ? tx('GELİŞMİŞ TEŞHİS ADAYI • {0}', [group ?? vehicle.brand]) : tx('STANDART OBD DESTEĞİ'), style: TextStyle(color: eligible ? AppColors.accentBright : Colors.white38, fontWeight: FontWeight.w700, fontSize: 11)),
          ])),
        ]),
        const SizedBox(height: 10),
        Text(OemVehicleSupport.selectedVehicleMessage(vehicle), style: const TextStyle(color: Colors.white60, fontSize: 10, height: 1.4)),
        if (eligible) ...[
          const SizedBox(height: 12),
          Row(children: [
            Icon(ecuConfirmed ? Icons.check_circle_rounded : Icons.pending_rounded, color: ecuConfirmed ? AppColors.success : Colors.amber, size: 16),
            const SizedBox(width: 7),
            Expanded(child: Text(ecuConfirmed ? tx('Araç ve motor kontrol ünitesi doğrulandı. Aşağıdaki özellikler canlı desteğe göre açıldı.') : tx('VIN okunduğunda motor kontrol ünitesi otomatik doğrulanacak.'), style: TextStyle(color: ecuConfirmed ? AppColors.success : Colors.amber, fontSize: 11, fontWeight: FontWeight.w600, height: 1.35))),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            _FeaturePill(label: tx('Turbo hedef'), active: turboTarget),
            _FeaturePill(label: tx('Turbo gerçek'), active: turboActual),
            _FeaturePill(label: tx('Yakıt basıncı'), active: rail),
            _FeaturePill(label: tx('EGR analizi'), active: egr),
            _FeaturePill(label: tx('DPF verileri'), active: dpf),
          ]),
          const SizedBox(height: 8),
          Text(tx('Yeşil özellikler araçtan gerçekten veri alındığında açılır. Araç seçimi tek başına “tam destek” sayılmaz.'), style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.35)),
        ],
      ]),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({required this.label, required this.active});
  final String label;
  final bool active;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(color: active ? const Color(0xFF10271A) : const Color(0xFF181818), borderRadius: BorderRadius.circular(20), border: Border.all(color: active ? AppColors.success.withValues(alpha: .45) : Colors.white10)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(active ? Icons.check_circle_rounded : Icons.lock_clock_rounded, color: active ? AppColors.success : Colors.white30, size: 13),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(color: active ? Colors.white : Colors.white38, fontSize: 11, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _OemDiagnosticCard extends StatelessWidget {
  const _OemDiagnosticCard({required this.obd});
  final ObdProvider obd;
  @override
  Widget build(BuildContext context) {
    final o=obd.oemDiscovery;
    final supported=o.identities.where((e)=>e.supported).toList();
    return Container(
      padding:const EdgeInsets.all(14),
      decoration:BoxDecoration(color:Theme.of(context).colorScheme.surfaceContainer,borderRadius:BorderRadius.circular(14),border:Border.all(color:Theme.of(context).colorScheme.outlineVariant)),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[const Icon(Icons.hub_rounded,color:AppColors.accentBright,size:20),const SizedBox(width:8),Expanded(child:Text(tx('ARAÇ SİSTEMLERİ'),style:TextStyle(color:Colors.white,fontWeight:FontWeight.w700,fontSize:13))),IconButton(tooltip:tx('Yeniden keşfet'),onPressed:obd.isOemScanning?null:()=>context.read<ObdProvider>().runOemDiscovery(),icon:obd.isOemScanning?const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.refresh_rounded,size:19))]),
        Text(o.catalogName != null ? tx('Aracınıza uygun gelişmiş teşhis desteği hazır.') : tx('Araç tanındığında desteklenen sistemler otomatik belirlenir.'),style:const TextStyle(color:Colors.white54,fontSize:10,height:1.35)),
        if(o.catalogName!=null)...[
          const SizedBox(height:9),
          Wrap(spacing:6,runSpacing:6,children:[
            _ScanChip(label:tx('Motor sistemi'),value:o.respondingCanIds.isNotEmpty?tx('BULUNDU'):'TARANACAK'),
            _ScanChip(label:tx('Araç kimliği'),value:supported.isNotEmpty?tx('OKUNDU'):'TARANACAK'),
            _ScanChip(label:tx('Gelişmiş teşhis'),value:tx('HAZIR')),
          ]),
          if(o.catalogExperimental) Padding(padding:EdgeInsets.only(top:8),child:Text(tx('Bazı marka özel veriler doğrulanana kadar yalnızca güvenli ve salt-okunur teşhis bilgileri kullanılır.'),style:TextStyle(color:Colors.amber,fontSize: 11,height:1.35,fontWeight:FontWeight.w700))),
        ],
        if(o.respondingCanIds.isNotEmpty)...[const SizedBox(height:9),Text(tx('Araç kontrol üniteleriyle iletişim kuruldu.'),style:TextStyle(color:AppColors.success,fontSize: 11,fontWeight:FontWeight.w600))],
        if(o.identities.isNotEmpty)...[
          const SizedBox(height:9),
          ...o.identities.map((e)=>Padding(padding:const EdgeInsets.only(bottom:5),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(e.supported?Icons.check_circle_rounded:Icons.remove_circle_outline_rounded,color:e.supported?AppColors.success:Colors.white24,size:15),const SizedBox(width:7),Expanded(child:Text('${e.label}\n${e.supported?e.value:(e.error ?? 'Desteklenmiyor')}',style:TextStyle(color:e.supported?Colors.white70:Colors.white38,fontSize: 11,height:1.3,fontWeight:e.supported?FontWeight.w700:FontWeight.w400)))]))),
        ] else if(!obd.isOemScanning) Padding(padding:EdgeInsets.only(top:9),child:Text(tx('Tam tarama veya yenile düğmesiyle araç sistemleri güvenli biçimde tanınabilir.'),style:TextStyle(color:Colors.white38,fontSize: 11))),
      ]),
    );
  }
}

class _FullScanCard extends StatelessWidget {
  const _FullScanCard({required this.obd});
  final ObdProvider obd;
  @override
  Widget build(BuildContext context) {
    final ff = obd.freezeFrame;
    final ready = obd.readiness;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(14), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children:[const Icon(Icons.document_scanner_rounded,color:AppColors.accentBright),const SizedBox(width:9),Expanded(child:Text(tx('TAM ARAÇ TARAMASI'),style:TextStyle(color:Colors.white,fontWeight:FontWeight.w700,fontSize:13))),Text(obd.lastFullScan==null?tx('HAZIR'):tx('TAMAMLANDI'),style:TextStyle(color:obd.lastFullScan==null?Colors.white54:AppColors.success,fontWeight:FontWeight.w700,fontSize: 11))]),
        const SizedBox(height:7),
        Text(tx('Araç kimliği • arıza kayıtları • emisyon hazırlığı • arıza anı verileri • canlı sensör özeti'),style:TextStyle(color:Colors.white54,fontSize:10,height:1.35)),
        const SizedBox(height:11),
        SizedBox(width:double.infinity,height:44,child:ElevatedButton.icon(onPressed:obd.isFullScanning?null:()=>context.read<ObdProvider>().runFullVehicleScan(),icon:obd.isFullScanning?const SizedBox(width:17,height:17,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.radar_rounded),label:Text(obd.isFullScanning?tx('ARAÇ TARANIYOR...'):tx('ARACI TAM TARA'),style:const TextStyle(fontWeight:FontWeight.w700)))),
        if(obd.lastFullScan!=null)...[
          const SizedBox(height:12),
          Wrap(spacing:7,runSpacing:7,children:[
            _ScanChip(label:'DTC',value:'${obd.dtcEntries.length}'),
            _ScanChip(label:tx('Canlı sensör'),value:'${obd.supportedPidCount}'),
            _ScanChip(label:'Readiness',value:ready.supported==0?'--':'${ready.completed}/${ready.supported}'),
            _ScanChip(label:tx('Arıza anı'),value:ff.hasData?tx('VAR'):tx('YOK')),
            _ScanChip(label:tx('Sistem testleri'),value:obd.mode06Raw.isEmpty?tx('YOK'):tx('VAR')),
          ]),
          const SizedBox(height:10),
          Text(tx('Adaptör: {0} • {1}', [obd.adapterInfo.identity, obd.adapterInfo.protocol]),style:const TextStyle(color:Colors.white54,fontSize: 11)),
          if(ff.hasData) Padding(padding:const EdgeInsets.only(top:6),child:Text('Freeze Frame${ff.triggerDtc==null?'':' • ${ff.triggerDtc}'}: ${ff.rpm??'-'} rpm • ${ff.speedKmh??'-'} km/h • ${ff.coolantC??'-'} °C • MAP ${ff.mapKpa??'-'} kPa',style:const TextStyle(color:Colors.white70,fontSize: 11,fontWeight:FontWeight.w700))),
        ]
      ]),
    );
  }
}

class _VinDetectionCard extends StatelessWidget {
  const _VinDetectionCard({required this.obd});
  final ObdProvider obd;
  @override Widget build(BuildContext context) {
    final vin=obd.detectedVin;
    final found=vin!=null&&vin.length==17;
    return Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF1D090B),Color(0xFF0D0D0D)]),borderRadius:BorderRadius.circular(14),border:Border.all(color:AppColors.accentBorder)),child:Row(children:[
      Container(width:46,height:46,decoration:BoxDecoration(color:AppColors.accentSoft,borderRadius:BorderRadius.circular(13)),child:Icon(found?Icons.verified_rounded:Icons.manage_search_rounded,color:found?AppColors.success:AppColors.accentBright)),
      const SizedBox(width:11),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(found?(obd.detectedBrand??tx('Marka belirlenemedi')):tx('VIN otomatik aranıyor'),style:const TextStyle(color:Colors.white,fontSize:13,fontWeight:FontWeight.w700)),const SizedBox(height:4),Text(found?vin!:tx('Mode 09 ve genel UDS F190 sırasıyla denenir'),maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:found?Colors.white70:Colors.white54,fontSize:10,fontWeight:found?FontWeight.w600:FontWeight.w400,letterSpacing:found?0.7:0))])),
      Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:5),decoration:BoxDecoration(color:(found?AppColors.success:Colors.amber).withValues(alpha:.10),borderRadius:BorderRadius.circular(20),border:Border.all(color:(found?AppColors.success:Colors.amber).withValues(alpha:.35))),child:Text(found?'ALGILANDI':tx('ARANIYOR'),style:TextStyle(color:found?AppColors.success:Colors.amber,fontSize: 11,fontWeight:FontWeight.w700))),
    ]));
  }
}
class _ScanChip extends StatelessWidget { const _ScanChip({required this.label,required this.value}); final String label,value; @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:6),decoration:BoxDecoration(color:const Color(0xFF171313),borderRadius:BorderRadius.circular(20),border:Border.all(color:const Color(0xFF382629))),child:Text('$label  $value',style:const TextStyle(color:Colors.white70,fontSize: 11,fontWeight:FontWeight.w600))); }

class _HealthScoreCard extends StatelessWidget {
  const _HealthScoreCard({required this.obd}); final ObdProvider obd;
  @override Widget build(BuildContext context) { final score = obd.vehicleHealthScore; final color = score >= 85 ? AppColors.success : score >= 65 ? Colors.amber : AppColors.danger; return Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:Theme.of(context).colorScheme.surfaceContainer,borderRadius:BorderRadius.circular(14),border:Border.all(color:color.withValues(alpha:.45))),child:Row(children:[SizedBox(width:62,height:62,child:Stack(alignment:Alignment.center,children:[CircularProgressIndicator(value:score/100,strokeWidth:6,color:color,backgroundColor:Colors.white10),Text(score==0?'--':'$score',style:TextStyle(color:color,fontWeight:FontWeight.w700,fontSize:18))])),const SizedBox(width:13),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('ARAÇ SAĞLIK PUANI',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w700,fontSize:12)),const SizedBox(height:5),Text(obd.vehicleHealthLabel,style:TextStyle(color:color,fontWeight:FontWeight.w700,fontSize:13)),const SizedBox(height:3),Text(obd.healthWarnings.isEmpty?'Canlı ECU verilerinde belirgin uyarı yok.':'${obd.healthWarnings.length} kontrol noktası dikkat istiyor.',style:const TextStyle(color:Colors.white54,fontSize:10))]))])); }
}

class _AdapterQualityCard extends StatelessWidget {
  const _AdapterQualityCard({required this.obd}); final ObdProvider obd;
  @override Widget build(BuildContext context) {final result=obd.adapterQuality;final score=result?.score;final color=score==null?AppColors.textMuted:score>=80?AppColors.success:score>=55?AppColors.warning:AppColors.danger;return Container(padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:Theme.of(context).colorScheme.surfaceContainer,borderRadius:BorderRadius.circular(13),border:Border.all(color:Theme.of(context).colorScheme.outlineVariant)),child:Row(children:[Container(width:43,height:43,alignment:Alignment.center,decoration:BoxDecoration(color:color.withValues(alpha:.13),borderRadius:BorderRadius.circular(12)),child:Text(score?.toString()??'--',style:TextStyle(color:color,fontWeight:FontWeight.w700,fontSize:16))),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('ADAPTÖR KALİTE PUANI',style:TextStyle(fontWeight:FontWeight.w700,fontSize:11)),Text(result==null?'Hız, paket kaybı ve uzun UDS desteğini ölç.':'${result.verdict} • ${result.successful}/${result.total} • ${result.averageMs} ms',style:TextStyle(color:Theme.of(context).colorScheme.onSurfaceVariant,fontSize: 11))])),SizedBox(height:34,child:OutlinedButton(onPressed:obd.isAdapterTesting?null:()=>context.read<ObdProvider>().testAdapterQuality(),child:Text(obd.isAdapterTesting?'TEST...':'TEST ET',style:const TextStyle(fontSize: 11,fontWeight:FontWeight.w700))))]));}
}

class _MaintenanceCard extends StatelessWidget {
  const _MaintenanceCard();
  @override Widget build(BuildContext context) { final provider=context.watch<MaintenanceProvider>(); final due=provider.dueItems; return Container(padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:Theme.of(context).colorScheme.surfaceContainer,borderRadius:BorderRadius.circular(13),border:Border.all(color:due.isEmpty?Theme.of(context).colorScheme.outlineVariant:Colors.amber.withValues(alpha:.45))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[const Icon(Icons.build_circle_outlined,color:AppColors.accentBright,size:21),const SizedBox(width:9),const Expanded(child:Text('BAKIM HATIRLATICILARI',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w700,fontSize:11))),Text(due.isEmpty?'GÜNCEL':'${due.length} GECİKTİ',style:TextStyle(color:due.isEmpty?AppColors.success:Colors.amber,fontWeight:FontWeight.w700,fontSize: 11))]),const SizedBox(height:8),...provider.items.take(3).map((item)=>Row(children:[Icon(item.isDue?Icons.warning_amber_rounded:Icons.check_circle_outline_rounded,color:item.isDue?Colors.amber:AppColors.success,size:15),const SizedBox(width:7),Expanded(child:Text(item.title,style:const TextStyle(color:Colors.white70,fontSize:10))),if(item.isDue) TextButton(onPressed:()=>context.read<MaintenanceProvider>().complete(item.id),child:const Text('TAMAM',style:TextStyle(fontSize: 11,fontWeight:FontWeight.w700))) ]))])); }
}

class _HeroStatus extends StatelessWidget {
  const _HeroStatus({required this.obd, required this.vehicleName});
  final ObdProvider obd;
  final String vehicleName;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1D090B), Color(0xFF0D0D0D)]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accentBorder),
      ),
      child: Row(children: [
        Container(width: 42, height: 42, decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.monitor_heart_rounded, color: AppColors.accentBright)),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(vehicleName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 3),
          Text(obd.protocolName ?? tx('OBD-II protokolü'), style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ])),
        Text(tx('ECU CANLI'), style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 10)),
      ]),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text); final String text;
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8, left: 2), child: Text(text, style: const TextStyle(color: AppColors.accentBright, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .7)));
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.icon, required this.title, required this.value, required this.subtitle, this.alert = false});
  final IconData icon; final String title; final String value; final String subtitle; final bool alert;
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(12), border: Border.all(color: alert ? AppColors.danger : Theme.of(context).colorScheme.outlineVariant)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, color: alert ? AppColors.danger : AppColors.accentBright, size: 16), const SizedBox(width: 6), Expanded(child: Text(title, style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w700)))]),
      const Spacer(),
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -.5)),
      const SizedBox(height: 2),
      Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: alert ? AppColors.danger : Colors.white38, fontSize: 11, height: 1.1)),
    ]),
  );
}

class _WarningTile extends StatelessWidget { const _WarningTile({required this.text}); final String text; @override Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 7), padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: .08), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.danger.withValues(alpha: .35))), child: Row(children:[const Icon(Icons.warning_amber_rounded,color:AppColors.danger,size:18),const SizedBox(width:8),Expanded(child:Text(text,style:const TextStyle(color:Colors.white70,fontSize:11,fontWeight:FontWeight.w700)))])); }
class _HealthyCard extends StatelessWidget { const _HealthyCard(); @override Widget build(BuildContext context) => _InfoPanel(text:tx('Canlı verilerde belirgin bir anormallik algılanmadı.')); }
class _InfoPanel extends StatelessWidget { const _InfoPanel({required this.text}); final String text; @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:Theme.of(context).colorScheme.surfaceContainer,borderRadius:BorderRadius.circular(10),border:Border.all(color:Theme.of(context).colorScheme.outlineVariant)),child:Text(text,style:TextStyle(color:Theme.of(context).colorScheme.onSurfaceVariant,fontSize:11))); }
enum _CapabilityStatus { full, partial, locked }
class _CapabilityTile extends StatelessWidget {
  const _CapabilityTile({required this.title, required this.subtitle, required this.status});
  final String title, subtitle; final _CapabilityStatus status;
  @override Widget build(BuildContext context) {
    final full=status==_CapabilityStatus.full, partial=status==_CapabilityStatus.partial;
    final color=full?AppColors.success:(partial?Colors.amber:Colors.white30);
    final icon=full?Icons.check_circle_rounded:(partial?Icons.timelapse_rounded:Icons.lock_outline_rounded);
    final label=full?tx('TAM DESTEK'):(partial?tx('KISMİ DESTEK'):tx('ECU-ÖZEL VERİ'));
    return Container(margin:const EdgeInsets.only(bottom:7),padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:const Color(0xFF101010),borderRadius:BorderRadius.circular(11),border:Border.all(color:color.withValues(alpha:.35))),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(icon,color:color,size:19),const SizedBox(width:9),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text(title,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w600,fontSize:12))),Container(padding:const EdgeInsets.symmetric(horizontal:7,vertical:3),decoration:BoxDecoration(color:color.withValues(alpha:.10),borderRadius:BorderRadius.circular(20)),child:Text(label,style:TextStyle(color:color,fontSize: 11,fontWeight:FontWeight.w700)))]),const SizedBox(height:4),Text(subtitle,style:const TextStyle(color:Color(0x73FFFFFF),fontSize:10,height:1.3))]))]));
  }
}
class _HistoryTile extends StatelessWidget { const _HistoryTile({required this.date,required this.total,required this.milOn}); final DateTime date; final int total; final bool? milOn; @override Widget build(BuildContext context)=>Container(margin:const EdgeInsets.only(bottom:7),padding:const EdgeInsets.symmetric(horizontal:12,vertical:10),decoration:BoxDecoration(color:const Color(0xFF101010),borderRadius:BorderRadius.circular(10),border:Border.all(color:const Color(0xFF282222))),child:Row(children:[const Icon(Icons.history_rounded,color:AppColors.accentBright,size:18),const SizedBox(width:9),Expanded(child:Text('${date.day.toString().padLeft(2,'0')}.${date.month.toString().padLeft(2,'0')}.${date.year}  ${date.hour.toString().padLeft(2,'0')}:${date.minute.toString().padLeft(2,'0')}',style:const TextStyle(color:Colors.white70,fontSize:11))),Text(tx('{0} kod', [total]),style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w700,fontSize:11)),const SizedBox(width:8),Icon(milOn==true?Icons.error_rounded:Icons.check_circle_rounded,color:milOn==true?AppColors.danger:AppColors.success,size:16)])); }
class _EmptyState extends StatelessWidget { const _EmptyState(); @override Widget build(BuildContext context)=>Center(child:Padding(padding:EdgeInsets.all(28),child:Column(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.link_rounded,color:AppColors.accentBright,size:54),SizedBox(height:12),Text(tx('Önce OBD bağlantısını kur'),textAlign:TextAlign.center,style:TextStyle(color:Colors.white,fontWeight:FontWeight.w700,fontSize:16)),SizedBox(height:7),Text(tx('Bağlantı kurulduğunda VIN otomatik okunur; canlı sensörler ve gelişmiş teşhis aynı ekranda açılır.'),textAlign:TextAlign.center,style:TextStyle(color:const Color(0x73FFFFFF),fontSize:12))]))); }
