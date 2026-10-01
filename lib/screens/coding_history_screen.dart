import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/coding_history_provider.dart';
import '../providers/obd_provider.dart';
import '../models/coding_backup_record.dart';

class CodingHistoryScreen extends StatelessWidget{
  const CodingHistoryScreen({super.key});
  @override Widget build(BuildContext context){
    final h=context.watch<CodingHistoryProvider>();
    final obd=context.watch<ObdProvider>();
    final rows=h.forVin(obd.detectedVin);
    return Scaffold(appBar:AppBar(title:const Text('Kodlama Yedekleri',style:TextStyle(fontWeight:FontWeight.w800))),body:rows.isEmpty?const Center(child:Text('Bu VIN için OtoSinyal kodlama yedeği yok.',style:TextStyle(color:Colors.white54))):ListView.builder(padding:const EdgeInsets.all(12),itemCount:rows.length,itemBuilder:(c,i){final r=rows[i];return Card(child:ListTile(title:Text(r.moduleName,style:const TextStyle(fontWeight:FontWeight.w700,fontSize:11)),subtitle:Text('DID ${r.did} • ${r.status.label}\n${r.createdAt.toLocal()}\nEski: ${r.originalHex}',maxLines:4,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:8.5)),trailing:r.canRollback?FilledButton(onPressed:()=>_rollback(context,r),child:const Text('GERİ AL',style:TextStyle(fontSize:8))):null));}));
  }
  Future<void> _rollback(BuildContext context,CodingBackupRecord r) async{
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Eski kod geri yüklensin mi?'),content:Text('${r.moduleName}\nDID ${r.did}\n\nYalnız bu VIN ve aynı ECU kimliği doğrulanırsa yazılacak.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('VAZGEÇ')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('GERİ YÜKLE'))]));
    if(ok!=true||!context.mounted)return;
    final result=await context.read<ObdProvider>().rollbackCodingBackup(r);
    if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(result.message),behavior:SnackBarBehavior.floating));
  }
}
