import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../providers/garage_provider.dart';
import '../providers/obd_provider.dart';
import '../services/dtc_dictionary.dart';
import '../services/diagnostic_report_service.dart';
import '../services/recovered_vag_catalog_service.dart';
import '../services/dtc_explanation_service.dart';
import '../models/vehicle.dart';
import 'package:otosinyal_obd2/l10n/tx.dart';

class DtcScreen extends StatefulWidget {
  const DtcScreen({super.key});
  @override State<DtcScreen> createState()=>_DtcScreenState();
}

class _DtcScreenState extends State<DtcScreen> {
  final _search=TextEditingController();
  String _query='';
  @override void dispose(){_search.dispose();super.dispose();}

  @override Widget build(BuildContext context){
    final obd=context.watch<ObdProvider>();
    final vehicle=context.watch<GarageProvider>().activeVehicle;
    final brand=vehicle?.brand??obd.detectedBrand??tx('Genel OBD');
    final entries=obd.dtcEntries.where((e){final q=_query.trim().toUpperCase();if(q.isEmpty)return true;final desc=DtcDictionary.getDescription(e.code,brand:brand).toUpperCase();return e.code.toUpperCase().contains(q)||desc.contains(q)||e.status.label.toUpperCase().contains(q);}).toList();
    final stored=obd.dtcEntries.where((e)=>e.status==DtcStatus.stored).length;
    final pending=obd.dtcEntries.where((e)=>e.status==DtcStatus.pending).length;
    final permanent=obd.dtcEntries.where((e)=>e.status==DtcStatus.permanent).length;

    return Scaffold(
      backgroundColor:Theme.of(context).scaffoldBackgroundColor,
      bottomNavigationBar:_DtcBottomBar(obd:obd,stored:stored,pending:pending,permanent:permanent),
      body:SafeArea(child:CustomScrollView(slivers:[
      SliverPadding(padding:const EdgeInsets.fromLTRB(16,14,16,0),sliver:SliverToBoxAdapter(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          Container(width:44,height:44,decoration:BoxDecoration(color:AppColors.danger.withValues(alpha:.12),borderRadius:BorderRadius.circular(15),border:Border.all(color:AppColors.danger.withValues(alpha:.32))),child:const Icon(Icons.car_crash_rounded,color:AppColors.danger,size:23)),
          const SizedBox(width:11),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(tx('DTC MERKEZİ'),style:TextStyle(color:Colors.white,fontSize:21,fontWeight:FontWeight.w700,letterSpacing:.4)),SizedBox(height:2),Text(tx('Oku • Ara • Sil • Doğrula'),style:TextStyle(color:Colors.white60,fontSize:10,fontWeight:FontWeight.w700))])),
          _ReportButton(enabled:obd.canQueryDtc),
        ]),
        const SizedBox(height:14),
        _VehicleDtcCard(obd:obd,vehicle:vehicle),
        const SizedBox(height:12),
        _SearchBox(controller:_search,onChanged:(v)=>setState(()=>_query=v)),
        const SizedBox(height:12),
        Row(children:[
          Expanded(child:_StatusStat(label:tx('KAYITLI'),value:stored,color:stored>0?AppColors.danger:AppColors.success,icon:Icons.error_rounded)),
          const SizedBox(width:7),
          Expanded(child:_StatusStat(label:tx('BEKLEYEN'),value:pending,color:pending>0?AppColors.warning:AppColors.success,icon:Icons.schedule_rounded)),
          const SizedBox(width:7),
          Expanded(child:_StatusStat(label:tx('KALICI'),value:permanent,color:permanent>0?AppColors.warning:AppColors.textMuted,icon:Icons.lock_clock_rounded)),
        ]),
        if(permanent>0)...[
          const SizedBox(height:12),
          const _PermanentInfoBanner(),
        ],
        if(obd.freezeFrame.hasData)...[
          const SizedBox(height:12),
          _FreezeFrameCard(frame:obd.freezeFrame),
        ],
        if(obd.dtcError!=null)...[const SizedBox(height:9),_MessageBanner(text:obd.dtcError!,color:AppColors.warning,icon:Icons.warning_amber_rounded)],
        const SizedBox(height:14),
      ]))),
      if(!obd.canQueryDtc)
        SliverFillRemaining(hasScrollBody:false,child:_Empty(icon:Icons.link_off_rounded,title:tx('ECU bağlantısı yok'),body:tx('OBD adaptörüne bağlanıp ECU oturumunu başlat. DTC okuma ve silme burada tek ekrandan yapılacak.'),color:AppColors.info))
      else if(obd.isReadingCodes)
        SliverFillRemaining(hasScrollBody:false,child:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[CircularProgressIndicator(color:AppColors.info),SizedBox(height:14),Text(tx('Stored • Pending • Permanent taranıyor'),style:TextStyle(color:Colors.white54,fontSize:11,fontWeight:FontWeight.w700))])))
      else if(obd.dtcEntries.isEmpty && _query.trim().isEmpty)
        SliverFillRemaining(hasScrollBody:false,child:_Empty(icon:obd.lastDtcCheck==null?Icons.manage_search_rounded:Icons.verified_rounded,title:obd.lastDtcCheck==null?tx('Henüz DTC taraması yapılmadı'):tx('Arıza kodu bulunmadı'),body:obd.lastDtcCheck==null?tx('Yukarıdaki “DTC OKU” butonuyla ECU hafızasını tara.'):tx('Standart OBD-II hafızası temiz görünüyor.'),color:obd.lastDtcCheck==null?AppColors.info:AppColors.success))
      else if(entries.isEmpty && _query.trim().isNotEmpty)
        SliverPadding(padding:const EdgeInsets.fromLTRB(16,0,16,28),sliver:SliverToBoxAdapter(child:_DictionaryLookup(code:_query,brand:brand)))
      else
        SliverPadding(padding:const EdgeInsets.fromLTRB(16,0,16,28),sliver:SliverList(delegate:SliverChildBuilderDelegate((context,index){if(index.isOdd)return const SizedBox(height:8);final itemIndex=index~/2;return _DtcTile(entry:entries[itemIndex],brand:brand);},childCount:entries.isEmpty?0:entries.length*2-1))),
    ])));
  }
}

class _PermanentInfoBanner extends StatelessWidget {
  const _PermanentInfoBanner();
  @override Widget build(BuildContext context)=>Container(
    padding:const EdgeInsets.all(12),
    decoration:BoxDecoration(color:AppColors.warning.withValues(alpha:.08),borderRadius:BorderRadius.circular(14),border:Border.all(color:AppColors.warning.withValues(alpha:.30))),
    child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Icon(Icons.lock_rounded,color:AppColors.warning,size:18),SizedBox(width:9),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(tx('PERMANENT DTC AYRI TUTULUR'),style:TextStyle(color:AppColors.warning,fontSize:10,fontWeight:FontWeight.w700)),
        SizedBox(height:3),
        Text(tx('Mode 04 kalıcı DTC kayıtlarını doğrudan silemez. ECU kendi testlerini başarıyla tamamladığında bu kayıtlar kendiliğinden temizlenir.'),style:TextStyle(color:Colors.white60,fontSize: 11,height:1.35)),
      ])),
    ]),
  );
}

class _VehicleDtcCard extends StatelessWidget{
  const _VehicleDtcCard({required this.obd,required this.vehicle});final ObdProvider obd;final dynamic vehicle;
  @override Widget build(BuildContext context){final ecuCount=obd.ecuModules.length; final vehicleVin=vehicle==null?'':'${vehicle.vin}'.trim(); final vin=vehicleVin.isNotEmpty?vehicleVin:(obd.detectedVin??''); final engine=vehicle==null?'':'${vehicle.engineCode}'.trim();return Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:Theme.of(context).colorScheme.surfaceContainer,borderRadius:BorderRadius.circular(18),border:Border.all(color:AppColors.info.withValues(alpha:.22))),child:Column(children:[Row(children:[Container(width:44,height:44,decoration:BoxDecoration(color:AppColors.info.withValues(alpha:.10),borderRadius:BorderRadius.circular(13)),child:const Icon(Icons.directions_car_filled_rounded,color:AppColors.info)),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(vehicle?.displayName??obd.detectedBrand??tx('Araç bekleniyor'),style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w700,fontSize:14)),const SizedBox(height:3),Text(vin.isEmpty?tx('VIN okunmadı'):vin,style:const TextStyle(color:Colors.white60,fontSize: 11,fontFamily:'monospace'))])),_LiveBadge(live:obd.isRealMode)]),const SizedBox(height:11),Row(children:[Expanded(child:_Tiny(label:'MOTOR',value:(engine!=null&&engine.isNotEmpty)?engine:'--')),const SizedBox(width:6),Expanded(child:_Tiny(label:tx('PROTOKOL'),value:obd.protocolName??'--')),const SizedBox(width:6),Expanded(child:_Tiny(label:'ECU',value:ecuCount==0?'--':tx('{0} modül', [ecuCount])))]) ]));}
}

class _SearchBox extends StatelessWidget{
  const _SearchBox({required this.controller,required this.onChanged});final TextEditingController controller;final ValueChanged<String> onChanged;
  @override Widget build(BuildContext context)=>TextField(controller:controller,onChanged:onChanged,textCapitalization:TextCapitalization.characters,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w600),decoration:InputDecoration(hintText:tx('DTC ara: P0401, turbo, EGR, ABS...'),hintStyle:const TextStyle(color:Colors.white54,fontSize:11),prefixIcon:const Icon(Icons.search_rounded,color:AppColors.info),suffixIcon:controller.text.isEmpty?null:IconButton(onPressed:(){controller.clear();onChanged('');},icon:const Icon(Icons.close_rounded,color:Colors.white38)),filled:true,fillColor:Theme.of(context).colorScheme.surfaceContainer,border:OutlineInputBorder(borderRadius:BorderRadius.circular(15),borderSide:BorderSide(color:Colors.white.withValues(alpha:.08))),enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(15),borderSide:BorderSide(color:Colors.white.withValues(alpha:.08))),focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(15),borderSide:const BorderSide(color:AppColors.info))));
}

class _DtcBottomBar extends StatelessWidget {
  const _DtcBottomBar({required this.obd,required this.stored,required this.pending,required this.permanent});
  final ObdProvider obd; final int stored,pending,permanent;
  @override Widget build(BuildContext context){
    final busy=obd.isReadingCodes||obd.isClearingCodes;
    final removable=stored+pending;
    final canClear=!busy&&removable>0;
    return Container(
      padding:const EdgeInsets.fromLTRB(16,8,16,8),
      decoration:BoxDecoration(color:AppColors.background,border:Border(top:BorderSide(color:Colors.white.withValues(alpha:.06),width:.5))),
      child:Row(children:[
        Expanded(child:SizedBox(height:44,child:FilledButton.icon(
          onPressed:busy||!obd.canQueryDtc?null:()=>context.read<ObdProvider>().readTroubleCodes(),
          icon:obd.isReadingCodes?const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.manage_search_rounded,size:19),
          label:Text(obd.isReadingCodes?tx('OKUNUYOR...'):tx('DTC OKU'),style:const TextStyle(fontWeight:FontWeight.w700,fontSize:13)),
          style:FilledButton.styleFrom(backgroundColor:AppColors.cardElevated,foregroundColor:Colors.white,disabledBackgroundColor:AppColors.cardBg,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),
        ))),
        const SizedBox(width:8),
        Expanded(child:SizedBox(height:44,child:OutlinedButton.icon(
          onPressed:canClear?()=>_confirmClear(context):null,
          icon:obd.isClearingCodes?const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.delete_sweep_rounded,size:19),
          label:Text(obd.isClearingCodes?tx('DOĞRULANIYOR...'):tx('SİLİNEBİLİRİ SİL ({0})', [removable]),maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w700,fontSize:13)),
          style:OutlinedButton.styleFrom(foregroundColor:AppColors.danger,side:BorderSide(color:canClear?AppColors.danger.withValues(alpha:.55):Colors.white.withValues(alpha:.08)),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),
        ))),
      ]),
    );
  }
  Future<void> _confirmClear(BuildContext context) async {
    final obd=context.read<ObdProvider>();
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      backgroundColor:const Color(0xFF151619),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(22)),
      title:Row(children:[Icon(Icons.delete_sweep_rounded,color:AppColors.danger),SizedBox(width:9),Expanded(child:Text(tx('Silinebilir DTC kayıtlarını temizle?'),style:TextStyle(color:Colors.white,fontWeight:FontWeight.w700)))]),
      content:Text(tx('Stored ve Pending OBD-II kayıtları için Mode 04 uygulanır. Permanent DTC kayıtları silinmez. İşlem sonrası ECU tekrar taranarak sonuç doğrulanır.'),style:TextStyle(color:Colors.white70,height:1.4)),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(tx('VAZGEÇ'))),FilledButton(onPressed:()=>Navigator.pop(ctx,true),style:FilledButton.styleFrom(backgroundColor:AppColors.danger),child:Text(tx('SİL VE DOĞRULA')))],
    ));
    if(ok!=true||!context.mounted)return;
    final success=await obd.clearTroubleCodes();
    if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(success?tx('DTC silme tamamlandı ve ECU yeniden doğrulandı'):obd.dtcError??tx('Bazı DTC kayıtları silinemedi'))));
  }
}

class _ActionBar extends StatelessWidget{
  const _ActionBar({required this.obd});final ObdProvider obd;
  @override Widget build(BuildContext context){final busy=obd.isReadingCodes||obd.isClearingCodes;return Row(children:[Expanded(child:ElevatedButton.icon(onPressed:busy?null:()=>context.read<ObdProvider>().readTroubleCodes(),style:ElevatedButton.styleFrom(backgroundColor:AppColors.info,foregroundColor:Colors.white,padding:const EdgeInsets.symmetric(vertical:14),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(15))),icon:const Icon(Icons.manage_search_rounded),label:Text(obd.isReadingCodes?'TARANIYOR...':tx('DTC OKU'),style:const TextStyle(fontWeight:FontWeight.w700)))),const SizedBox(width:8),Expanded(child:ElevatedButton.icon(onPressed:busy||obd.dtcEntries.isEmpty?null:()=>_confirmClear(context),style:ElevatedButton.styleFrom(backgroundColor:AppColors.danger.withValues(alpha:.13),foregroundColor:AppColors.danger,disabledBackgroundColor:Colors.white.withValues(alpha:.035),disabledForegroundColor:Colors.white24,padding:const EdgeInsets.symmetric(vertical:14),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(15),side:BorderSide(color:(busy||obd.dtcEntries.isEmpty)?Colors.white10:AppColors.danger.withValues(alpha:.5)))),icon:const Icon(Icons.delete_sweep_rounded),label:Text(obd.isClearingCodes?tx('DOĞRULANIYOR...'):tx('DTC SİL'),style:const TextStyle(fontWeight:FontWeight.w700))))]);}
  Future<void> _confirmClear(BuildContext context) async {final obd=context.read<ObdProvider>();final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(backgroundColor:const Color(0xFF151619),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(22)),title:Row(children:[Icon(Icons.delete_sweep_rounded,color:AppColors.danger),SizedBox(width:9),Expanded(child:Text(tx('DTC hafızasını temizle?'),style:TextStyle(color:Colors.white,fontWeight:FontWeight.w700)))]),content:Text(tx('Mode 04 kayıtlı OBD-II arızalarını temizler. Permanent kodlar ECU koşulları sağlanana kadar kalabilir. OTOSİNYAL işlemden sonra kodları yeniden okuyup sonucu doğrular.'),style:TextStyle(color:Colors.white60,height:1.45)),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(tx('VAZGEÇ'))),ElevatedButton(onPressed:()=>Navigator.pop(ctx,true),style:ElevatedButton.styleFrom(backgroundColor:AppColors.danger,foregroundColor:Colors.white),child:Text(tx('SİL VE DOĞRULA'),style:TextStyle(fontWeight:FontWeight.w700)))]));if(ok!=true||!context.mounted)return;final success=await obd.clearTroubleCodes();if(!context.mounted)return;ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor:success?AppColors.success:AppColors.warning,content:Text(success?tx('DTC hafızası temizlendi ve yeniden tarandı.'):obd.dtcError??tx('Bazı kodlar silinemedi.'))));}
}

class _DtcTile extends StatelessWidget{
  const _DtcTile({required this.entry,required this.brand});final DtcEntry entry;final String brand;
  Color get color=>entry.status==DtcStatus.stored?AppColors.danger:entry.status==DtcStatus.pending?AppColors.warning:AppColors.textMuted;
  @override Widget build(BuildContext context){final specific=DtcDictionary.isManufacturerSpecific(entry.code);final fallback=DtcDictionary.getDescription(entry.code,brand:brand);return Material(color:Colors.transparent,child:InkWell(borderRadius:BorderRadius.circular(17),onTap:()=>_showDtcDetail(context),child:Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:Theme.of(context).colorScheme.surfaceContainer,borderRadius:BorderRadius.circular(17),border:Border.all(color:color.withValues(alpha:.28))),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Container(width:43,height:43,decoration:BoxDecoration(color:color.withValues(alpha:.11),borderRadius:BorderRadius.circular(13)),child:Icon(entry.status==DtcStatus.permanent?Icons.lock_clock_rounded:Icons.warning_amber_rounded,color:color,size:21)),const SizedBox(width:11),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Text(entry.code,style:const TextStyle(color:Colors.white,fontSize:16,fontWeight:FontWeight.w700,letterSpacing:.5)),const Spacer(),_Pill(text:entry.status.label,color:color)]),const SizedBox(height:5),FutureBuilder<String?>(future:RecoveredVagCatalogService.lookupDtc(entry.code),builder:(context,snapshot)=>Text((snapshot.data?.trim().isNotEmpty??false)?snapshot.data!:fallback,style:const TextStyle(color:Colors.white60,fontSize:11,height:1.35))),const SizedBox(height:7),Row(children:[if(specific)_Pill(text:tx('ÜRETİCİ-ÖZEL'),color:AppColors.info),const Spacer(),Text(tx('DETAY ›'),style:TextStyle(color:AppColors.info,fontSize: 11,fontWeight:FontWeight.w900))])]))]))));}
  Future<void> _showDtcDetail(BuildContext context) async {final exp=await DtcExplanationService.explain(entry.code,brand:brand);if(!context.mounted)return;showModalBottomSheet(context:context,isScrollControlled:true,backgroundColor:const Color(0xFF111214),shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(24))),builder:(ctx)=>DraggableScrollableSheet(expand:false,initialChildSize:.72,maxChildSize:.94,minChildSize:.45,builder:(ctx,scroll)=>ListView(controller:scroll,padding:const EdgeInsets.fromLTRB(18,10,18,28),children:[Center(child:Container(width:42,height:4,decoration:BoxDecoration(color:Colors.white24,borderRadius:BorderRadius.circular(9)))),const SizedBox(height:16),Row(children:[Text(exp.code,style:const TextStyle(color:Colors.white,fontSize:27,fontWeight:FontWeight.w900)),const Spacer(),_Pill(text:exp.severity.toUpperCase(),color:exp.severity==tx('Yüksek')?AppColors.danger:exp.severity==tx('Orta')?AppColors.warning:AppColors.info)]),const SizedBox(height:6),Text(exp.title,style:const TextStyle(color:Colors.white70,fontSize:13,fontWeight:FontWeight.w700,height:1.4)),const SizedBox(height:18),_SectionTitle(tx('MUHTEMEL NEDENLER')),...exp.possibleCauses.map((x)=>_DetailBullet(x,Icons.error_outline_rounded,AppColors.warning)),const SizedBox(height:12),_SectionTitle(tx('KONTROL EDİLECEKLER')),...exp.checks.map((x)=>_DetailBullet(x,Icons.build_circle_outlined,AppColors.info)),const SizedBox(height:12),_SectionTitle(tx('SÜRÜŞ ÖNERİSİ')),Container(padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:AppColors.danger.withValues(alpha:.07),borderRadius:BorderRadius.circular(14),border:Border.all(color:AppColors.danger.withValues(alpha:.2))),child:Text(exp.drivingAdvice,style:const TextStyle(color:Colors.white70,fontSize:10.5,height:1.45))),])));}
}

class _FreezeFrameCard extends StatelessWidget {
  const _FreezeFrameCard({required this.frame});
  final FreezeFrameSnapshot frame;

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, String)>[
      if (frame.rpm != null) (Icons.speed_rounded, 'RPM', '${frame.rpm}'),
      if (frame.speedKmh != null) (Icons.directions_car_filled_rounded, tx('Hız'), '${frame.speedKmh} km/h'),
      if (frame.coolantC != null) (Icons.thermostat_rounded, tx('Su sıcaklığı'), '${frame.coolantC} °C'),
      if (frame.loadPercent != null) (Icons.bolt_rounded, tx('Motor yükü'), '%${frame.loadPercent}'),
      if (frame.mapKpa != null) (Icons.compress_rounded, 'MAP', '${frame.mapKpa} kPa'),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: .06)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.photo_camera_back_rounded, color: AppColors.info, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tx('Arıza anı verisi'), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              Text(tx('Arıza kaydedildiği andaki motor değerleri (freeze frame)'), style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
            ]),
          ),
          if (frame.triggerDtc != null) _Pill(text: frame.triggerDtc!, color: AppColors.warning),
        ]),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, constraints) {
            const gap = 8.0;
            final columns = constraints.maxWidth >= 330 ? 3 : 2;
            final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final item in items)
                  SizedBox(
                    width: width,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
                      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Icon(item.$1, size: 14, color: AppColors.textMuted),
                          const SizedBox(width: 5),
                          Expanded(child: Text(item.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5, fontWeight: FontWeight.w600))),
                        ]),
                        const SizedBox(height: 5),
                        Text(item.$3, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
              ],
            );
          }),
        ],
      ]),
    );
  }
}

class _SectionTitle extends StatelessWidget{const _SectionTitle(this.text);final String text;@override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.only(bottom:7),child:Text(text,style:const TextStyle(color:AppColors.info,fontSize: 11,fontWeight:FontWeight.w900,letterSpacing:.8)));}
class _DetailBullet extends StatelessWidget{const _DetailBullet(this.text,this.icon,this.color);final String text;final IconData icon;final Color color;@override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.only(bottom:7),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(icon,color:color,size:16),const SizedBox(width:8),Expanded(child:Text(text,style:const TextStyle(color:Colors.white60,fontSize:10.5,height:1.4)))]));}

class _DictionaryLookup extends StatelessWidget{
  const _DictionaryLookup({required this.code,required this.brand});final String code,brand;
  @override Widget build(BuildContext context){final normalized=code.trim().toUpperCase();final looksLike=RegExp(r'^[PBCU][0-9A-F]{4}$').hasMatch(normalized);final fallback=DtcDictionary.getDescription(normalized,brand:brand);return Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:Theme.of(context).colorScheme.surfaceContainer,borderRadius:BorderRadius.circular(18),border:Border.all(color:AppColors.info.withValues(alpha:.25))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Icon(Icons.menu_book_rounded,color:AppColors.info),SizedBox(width:8),Text(tx('DTC SÖZLÜĞÜ'),style:TextStyle(color:AppColors.info,fontWeight:FontWeight.w700,fontSize:11))]),const SizedBox(height:11),Text(looksLike?normalized:tx('Sonuç bulunamadı'),style:const TextStyle(color:Colors.white,fontSize:19,fontWeight:FontWeight.w700)),const SizedBox(height:5),if(looksLike)FutureBuilder<String?>(future:RecoveredVagCatalogService.lookupDtc(normalized),builder:(context,snapshot)=>Text((snapshot.data?.trim().isNotEmpty??false)?snapshot.data!:fallback,style:const TextStyle(color:Colors.white54,fontSize:11,height:1.4)))else Text(tx('Kod veya açıklama ile ara. Örnek: P0401, EGR, turbo.'),style:TextStyle(color:Colors.white54,fontSize:11,height:1.4))]));}
}

class _StatusStat extends StatelessWidget{const _StatusStat({required this.label,required this.value,required this.color,required this.icon});final String label;final int value;final Color color;final IconData icon;@override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:10),decoration:BoxDecoration(color:color.withValues(alpha:.07),borderRadius:BorderRadius.circular(13),border:Border.all(color:color.withValues(alpha:.22))),child:Row(children:[Icon(icon,color:color,size:16),const SizedBox(width:6),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:const TextStyle(color:Colors.white60,fontSize: 11,fontWeight:FontWeight.w700)),Text('$value',style:TextStyle(color:color,fontSize:15,fontWeight:FontWeight.w700))]))]));}
class _Tiny extends StatelessWidget{const _Tiny({required this.label,required this.value});final String label,value;@override Widget build(BuildContext context)=>Container(height:50,padding:const EdgeInsets.symmetric(horizontal:8,vertical:7),decoration:BoxDecoration(color:Colors.black.withValues(alpha:.22),borderRadius:BorderRadius.circular(11),border:Border.all(color:Colors.white.withValues(alpha:.06))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:const TextStyle(color:Colors.white54,fontSize: 11,fontWeight:FontWeight.w700)),const SizedBox(height:4),Expanded(child:Text(value,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white70,fontSize: 11,fontWeight:FontWeight.w600)))]));}
class _LiveBadge extends StatelessWidget{const _LiveBadge({required this.live});final bool live;@override Widget build(BuildContext context){final c=live?AppColors.info:AppColors.textMuted;return Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:5),decoration:BoxDecoration(color:c.withValues(alpha:.09),borderRadius:BorderRadius.circular(20),border:Border.all(color:c.withValues(alpha:.35))),child:Row(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.circle,color:c,size:6),const SizedBox(width:5),Text(live?tx('ECU CANLI'):tx('PASİF'),style:TextStyle(color:c,fontSize: 11,fontWeight:FontWeight.w700))]));}}
class _Pill extends StatelessWidget{const _Pill({required this.text,required this.color});final String text;final Color color;@override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.symmetric(horizontal:7,vertical:3),decoration:BoxDecoration(color:color.withValues(alpha:.11),borderRadius:BorderRadius.circular(20)),child:Text(text,style:TextStyle(color:color,fontSize: 11,fontWeight:FontWeight.w700)));}
class _MessageBanner extends StatelessWidget{const _MessageBanner({required this.text,required this.color,required this.icon});final String text;final Color color;final IconData icon;@override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(11),decoration:BoxDecoration(color:color.withValues(alpha:.09),borderRadius:BorderRadius.circular(13),border:Border.all(color:color.withValues(alpha:.25))),child:Row(children:[Icon(icon,color:color,size:18),const SizedBox(width:8),Expanded(child:Text(text,style:TextStyle(color:color,fontSize:10.5,fontWeight:FontWeight.w700)))]));}
class _Empty extends StatelessWidget{const _Empty({required this.icon,required this.title,required this.body,required this.color});final IconData icon;final String title,body;final Color color;@override Widget build(BuildContext context)=>Center(child:Padding(padding:const EdgeInsets.all(28),child:Column(mainAxisSize:MainAxisSize.min,children:[Container(width:82,height:82,decoration:BoxDecoration(color:color.withValues(alpha:.08),shape:BoxShape.circle,border:Border.all(color:color.withValues(alpha:.22))),child:Icon(icon,color:color,size:36)),const SizedBox(height:17),Text(title,textAlign:TextAlign.center,style:const TextStyle(color:Colors.white,fontSize:18,fontWeight:FontWeight.w700)),const SizedBox(height:7),Text(body,textAlign:TextAlign.center,style:const TextStyle(color:Colors.white60,fontSize:11,height:1.45))])));}
class _ReportButton extends StatelessWidget{const _ReportButton({required this.enabled});final bool enabled;@override Widget build(BuildContext context)=>IconButton(tooltip:tx('PDF raporu'),onPressed:enabled?()async{final obd=context.read<ObdProvider>();final vehicle=context.read<GarageProvider>().activeVehicle;final messenger=ScaffoldMessenger.of(context);final reportVehicle=vehicle??Vehicle(id:'report',brand:obd.detectedBrand??tx('Bilinmeyen araç'),model:'',plate:'',vin:obd.detectedVin??'');try{await DiagnosticReportService.createAndShare(vehicle:reportVehicle,obd:obd);}catch(error){messenger.showSnackBar(SnackBar(content:Text(tx('PDF hazırlanamadı. Lütfen tekrar deneyin.'))));}}:null,icon:Icon(Icons.picture_as_pdf_rounded,color:enabled?AppColors.info:Colors.white.withValues(alpha: 0.20)));}
