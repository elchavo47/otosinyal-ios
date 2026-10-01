import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../services/recovered_vag_adaptation_service.dart';
import 'recovered_vag_adaptations_screen.dart';
import 'vag_long_coding_screen.dart';
import 'coding_history_screen.dart';

class CodingScreen extends StatelessWidget {
  const CodingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kodlama ve Servis', style: TextStyle(fontWeight: FontWeight.w700))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainer,borderRadius:BorderRadius.circular(16),border:Border.all(color:AppColors.accentBorder)),
            child: const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('VAG PLATFORMUNU SEÇ',style:TextStyle(color:AppColors.accentBright,fontSize:12,fontWeight:FontWeight.w700,letterSpacing:.7)),
              SizedBox(height:5),
              Text('Araç modeli seçmek zorunda değilsin. Platformu seç; ardından kodlamalar eski motordaki gibi bölümlere ayrılır.',style:TextStyle(color:Colors.white54,fontSize: 11,height:1.4)),
            ]),
          ),
          const SizedBox(height:12),
          Container(
            margin: const EdgeInsets.only(bottom:10),
            decoration: BoxDecoration(color:AppColors.accentBright.withValues(alpha:.10),borderRadius:BorderRadius.circular(15),border:Border.all(color:AppColors.accentBright.withValues(alpha:.45))),
            child: ListTile(
              onTap:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>const VagLongCodingScreen())),
              leading:const Icon(Icons.memory_rounded,color:AppColors.accentBright),
              title:const Text('VAG LONG CODING • GERÇEK ECU',style:TextStyle(fontSize:12,fontWeight:FontWeight.w900)),
              subtitle:const Text('0x0600 oku • byte/bit düzenle • otomatik yedek • 0x2E yaz • doğrula • gerekirse rollback',style:TextStyle(fontSize: 11,color:Colors.white60)),
              trailing:const Icon(Icons.chevron_right_rounded,color:AppColors.accentBright),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(bottom:12),
            decoration: BoxDecoration(color:Theme.of(context).colorScheme.surfaceContainer,borderRadius:BorderRadius.circular(14),border:Border.all(color:Theme.of(context).colorScheme.outlineVariant)),
            child: ListTile(
              onTap:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>const CodingHistoryScreen())),
              leading:const Icon(Icons.history_rounded,color:Colors.white70),
              title:const Text('Kodlama Yedekleri / Geri Alma',style:TextStyle(fontSize:11,fontWeight:FontWeight.w800)),
              subtitle:const Text('Yazma öncesi alınan VIN + ECU kimlikli yedekleri gör ve doğrulanmış değere geri dön.',style:TextStyle(fontSize: 11,color:Colors.white54)),
              trailing:const Icon(Icons.chevron_right_rounded),
            ),
          ),
          ...RecoveredVagAdaptationService.supportedPlatforms.map((p)=>_PlatformTile(platform:p,onTap:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>RecoveredVagAdaptationsScreen(initialPlatform:p))))),
        ],
      ),
    );
  }
}

class _PlatformTile extends StatelessWidget {
  const _PlatformTile({required this.platform,required this.onTap});
  final String platform; final VoidCallback onTap;
  String get subtitle => switch(platform){
    'MQB'=>'Golf 7 / A3 8V / Octavia 3 / Leon 5F ve MQB ailesi',
    'MLB-A4B9'=>'MLB / Audi A4-B9 ve uyumlu VAG platformları',
    'PQ26'=>'PQ26 platformu',
    'PQ26-NEW-RAPID-2020'=>'Yeni PQ26 / Rapid 2020 ailesi',
    'PQ35'=>'PQ35 platformu',
    'MEB'=>'Elektrikli MEB platformu',
    'MQB-CAMERA-FUSION'=>'MQB kamera / fusion özel işlemleri',
    'MQB-SWAP-CUSTOM-CODING'=>'MQB SWaP / özel kodlama',
    _=>'Kurtarılan VAG kodlama kataloğu'};
  @override Widget build(BuildContext context)=>Container(
    margin:const EdgeInsets.only(bottom:9),
    decoration:BoxDecoration(color:Theme.of(context).colorScheme.surfaceContainer,borderRadius:BorderRadius.circular(14),border:Border.all(color:Theme.of(context).colorScheme.outlineVariant)),
    child:ListTile(onTap:onTap,contentPadding:const EdgeInsets.symmetric(horizontal:14,vertical:6),leading:Container(width:42,height:42,decoration:BoxDecoration(color:AppColors.accentBright.withValues(alpha:.10),borderRadius:BorderRadius.circular(12)),child:const Icon(Icons.hub_rounded,color:AppColors.accentBright)),title:Text(platform,style:const TextStyle(fontWeight:FontWeight.w700,fontSize:13)),subtitle:Text(subtitle,style:const TextStyle(color:Colors.white54,fontSize: 11)),trailing:const Icon(Icons.chevron_right_rounded,color:AppColors.accentBright)));
}
