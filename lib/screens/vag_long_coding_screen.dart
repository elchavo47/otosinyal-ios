import '../services/ios_share_origin.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../core/app_colors.dart';
import '../models/vag_long_coding.dart';
import '../providers/coding_history_provider.dart';
import '../providers/obd_provider.dart';
import '../services/vag_long_coding_service.dart';
import 'package:otosinyal_obd2/l10n/tx.dart';

class VagLongCodingScreen extends StatefulWidget {
  const VagLongCodingScreen({super.key});
  @override State<VagLongCodingScreen> createState()=>_VagLongCodingScreenState();
}

class _VagLongCodingScreenState extends State<VagLongCodingScreen>{
  VagLongCodingModule _module=VagLongCodingService.modules.first;
  VagLongCodingReadResult? _read;
  final _hex=TextEditingController();
  bool _busy=false;
  int _byteIndex=0;
  String _platform='MQB';

  @override void dispose(){_hex.dispose();super.dispose();}
  List<int> get _bytes=>VagLongCodingService.parseHex(_hex.text)??const [];

  Future<void> _readCoding() async{
    setState(()=>_busy=true);
    final r=await context.read<ObdProvider>().readVagLongCoding(_module);
    if(!mounted)return;
    setState((){_read=r;_busy=false;if(r.valueHex!=null){_hex.text=r.valueHex!;_byteIndex=0;}});
  }

  void _toggleBit(int bit){
    final b=List<int>.from(_bytes); if(b.isEmpty||_byteIndex>=b.length)return;
    b[_byteIndex]=(b[_byteIndex]^(1<<bit))&0xFF;
    setState(()=>_hex.text=VagLongCodingService.hex(b));
  }

  Future<void> _write() async{
    if(!_module.writeAllowed||_module.safetyCritical)return;
    final original=_read?.valueHex;
    if(original==null){_toast(tx('Önce ECU’dan mevcut Long Coding değerini oku.'));return;}
    final requested=_hex.text.replaceAll(RegExp(r'[^0-9A-Fa-f]'),'').toUpperCase();
    if(requested==original){_toast(tx('Değer değişmedi.'));return;}
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(
      title:Text(tx('Long Coding yazılsın mı?')),
      content:Text(tx('{0}\n\nÖnce mevcut değer kalıcı yedeklenecek. Yazma sonrası ECU tekrar okunacak; doğrulama tutmazsa otomatik eski koda dönülecek.\n\n{1} byte → {2} byte', [_module.name, original.length~/2, requested.length~/2])),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:Text(tx('VAZGEÇ'))),FilledButton(onPressed:()=>Navigator.pop(c,true),child:Text(tx('YEDEKLE VE YAZ')))],
    ));
    if(ok!=true||!mounted)return;
    setState(()=>_busy=true);
    final result=await context.read<ObdProvider>().writeVagLongCoding(module:_module,requestedHex:requested,history:context.read<CodingHistoryProvider>());
    if(!mounted)return; setState(()=>_busy=false); _toast(result.message);
    if(result.success)await _readCoding();
  }

  Future<void> _backup() async{
    setState(()=>_busy=true);
    try{
      final commands=await VagLongCodingService.backupCommands(_platform,_module.module);
      if(commands.isEmpty){_toast(tx('{0} / {1} için recovery backup listesi yok.', [_platform, _module.module]));return;}
      final snap=await context.read<ObdProvider>().captureVagModuleBackup(module:_module,commands:commands);
      final dir=await getTemporaryDirectory();
      final file=File('${dir.path}/OTOSINYAL_${_platform}_${_module.module}_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert({
        'format':'OTOSINYAL VAG read-only full module backup v1','platform':_platform,'module':snap.module,'moduleName':snap.moduleName,
        'requestId':snap.requestId,'responseId':snap.responseId,'createdAt':snap.createdAt.toIso8601String(),'attempted':snap.attempted,'succeeded':snap.succeeded,'values':snap.values,
      }));
      await Share.shareXFiles([XFile(file.path)],text:tx('OtoSinyal VAG modül yedeği • {0} • {1}/{2} DID', [snap.moduleName, snap.succeeded, snap.attempted]), sharePositionOrigin: otoShareOrigin());
      _toast(tx('{0}/{1} DID okundu ve yedek hazırlandı.', [snap.succeeded, snap.attempted]));
    }catch(e){_toast(tx('Modül yedeği alınamadı: {0}', [e]));}
    finally{if(mounted)setState(()=>_busy=false);}
  }

  void _toast(String s)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s),behavior:SnackBarBehavior.floating));

  @override Widget build(BuildContext context){
    final bytes=_bytes;
    return Scaffold(appBar:AppBar(title:const Text('VAG Long Coding',style:TextStyle(fontWeight:FontWeight.w800))),body:ListView(padding:const EdgeInsets.fromLTRB(14,12,14,30),children:[
      Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:Theme.of(context).colorScheme.surfaceContainer,borderRadius:BorderRadius.circular(16),border:Border.all(color:AppColors.accentBorder)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(tx('GERÇEK ECU LONG CODING'),style:TextStyle(color:AppColors.accentBright,fontWeight:FontWeight.w900,fontSize:12)),SizedBox(height:5),Text(tx('DID 0600 okunur. Yazılabilir modüllerde read → yedek → 2E0600 write → read-back verify → gerekirse rollback zinciri kullanılır. ABS/Airbag/Motor gibi güvenlik kritik modüllerde ham yazma kapalıdır.'),style:TextStyle(color:Colors.white60,fontSize:9,height:1.45))])),
      const SizedBox(height:12),
      DropdownButtonFormField<VagLongCodingModule>(value:_module,decoration:InputDecoration(labelText:tx('Kontrol ünitesi')),items:VagLongCodingService.modules.map((m)=>DropdownMenuItem(value:m,child:Text(m.name))).toList(),onChanged:_busy?null:(m)=>setState((){if(m!=null){_module=m;_read=null;_hex.clear();_byteIndex=0;}})),
      const SizedBox(height:10),
      Row(children:[Expanded(child:FilledButton.icon(onPressed:_busy?null:_readCoding,icon:const Icon(Icons.download_rounded),label:Text(_busy?tx('İŞLEM...'):tx('ECU’DAN OKU')))),const SizedBox(width:8),Expanded(child:OutlinedButton.icon(onPressed:_busy?null:_backup,icon:const Icon(Icons.backup_rounded),label:Text(tx('TAM YEDEK'))))]),
      if(_read!=null)...[const SizedBox(height:10),Container(padding:const EdgeInsets.all(11),decoration:BoxDecoration(color:(_read!.success?Colors.green:Colors.amber).withValues(alpha:.08),borderRadius:BorderRadius.circular(12)),child:Text('${_read!.message}${_read!.partNumber==null?'':tx('\nParça: {0}', [_read!.partNumber])}${_read!.softwareVersion==null?'':' • SW: ${_read!.softwareVersion}'}',style:const TextStyle(fontSize:9,height:1.4)))],
      const SizedBox(height:12),
      TextField(controller:_hex,enabled:_read?.success==true&&!_busy,maxLines:4,style:const TextStyle(fontFamily:'monospace',fontSize:11,letterSpacing:.7),onChanged:(_)=>setState((){}),decoration:InputDecoration(labelText:'Long Coding HEX',hintText:tx('Önce ECU’dan oku'),alignLabelWithHint:true)),
      if(bytes.isNotEmpty)...[
        const SizedBox(height:12),Text(tx('BYTE SEÇ'),style:TextStyle(fontSize:9,color:Colors.white54,fontWeight:FontWeight.w800)),const SizedBox(height:6),
        SizedBox(height:44,child:ListView.separated(scrollDirection:Axis.horizontal,itemCount:bytes.length,separatorBuilder:(_,__)=>const SizedBox(width:6),itemBuilder:(c,i)=>ChoiceChip(selected:_byteIndex==i,label:Text('$i\n${bytes[i].toRadixString(16).padLeft(2,'0').toUpperCase()}',textAlign:TextAlign.center,style:const TextStyle(fontSize:8)),onSelected:(_)=>setState(()=>_byteIndex=i)))),
        const SizedBox(height:10),Wrap(spacing:7,runSpacing:7,children:List.generate(8,(bit){final on=(bytes[_byteIndex]&(1<<bit))!=0;return FilterChip(selected:on,label:Text('Bit $bit • ${on?1:0}'),onSelected:(_)=>_toggleBit(bit));})),
      ],
      const SizedBox(height:14),
      if(!_module.writeAllowed||_module.safetyCritical)Container(padding:const EdgeInsets.all(11),decoration:BoxDecoration(color:Colors.amber.withValues(alpha:.08),borderRadius:BorderRadius.circular(12)),child:Text(tx('{0} için ham yazma kilitli; okuma ve recovery yedeği kullanılabilir.', [_module.name]),style:const TextStyle(color:Colors.amber,fontSize:9))),
      const SizedBox(height:9),SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:_busy||!_module.writeAllowed||_module.safetyCritical||_read?.success!=true?null:_write,icon:const Icon(Icons.verified_user_rounded),label:Text(tx('YEDEKLE • YAZ • DOĞRULA')))),
      const SizedBox(height:16),DropdownButtonFormField<String>(value:_platform,decoration:InputDecoration(labelText:tx('Tam yedek kataloğu platformu')),items:const ['MQB','PQ26','PQ262020','MLBEVO'].map((p)=>DropdownMenuItem(value:p,child:Text(p))).toList(),onChanged:_busy?null:(v)=>setState(()=>_platform=v??'MQB')),
      const SizedBox(height:5),Text(tx('Tam yedek recovery’deki .backup.xx listelerindeki 0x22 DID’leri yalnızca okur ve JSON dışa aktarır. Toplu ham restore yapılmaz; OtoSinyal’in yazmadan önce aldığı tekil coding/adaptation yedekleri doğrulanarak geri alınır.'),style:TextStyle(color:Colors.white38,fontSize:8,height:1.4)),
    ]));
  }
}
