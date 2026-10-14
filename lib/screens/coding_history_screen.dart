import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/coding_history_provider.dart';
import '../providers/obd_provider.dart';
import '../models/coding_backup_record.dart';
import 'package:otosinyal_obd2/l10n/tx.dart';

class CodingHistoryScreen extends StatelessWidget{
  const CodingHistoryScreen({super.key});
  @override Widget build(BuildContext context){
    final h=context.watch<CodingHistoryProvider>();
    final obd=context.watch<ObdProvider>();
    final vin=obd.detectedVin;
    // Araç bağlı değilken tüm yedekler listelenir (Ayarlar'dan erişim);
    // geri alma yalnız aynı VIN'li araç canlı bağlıyken yapılabilir.
    final rows=vin==null?h.records:h.forVin(vin);
    return Scaffold(
      appBar:AppBar(title:Text(tx('Kodlama Yedekleri'),style:const TextStyle(fontWeight:FontWeight.w800))),
      body:rows.isEmpty
        ?Center(child:Padding(padding:const EdgeInsets.all(24),child:Text(vin==null?tx('Henüz kodlama yedeği yok.'):tx('Bu VIN için OtoSinyal kodlama yedeği yok.'),textAlign:TextAlign.center,style:const TextStyle(color:Colors.white54))))
        :ListView.builder(
          padding:const EdgeInsets.all(12),
          itemCount:rows.length+(vin==null?1:0),
          itemBuilder:(c,i){
            if(vin==null&&i==0){
              return Padding(padding:const EdgeInsets.fromLTRB(4,0,4,10),child:Text(tx('Geri almak için aynı araca bağlan. Yedekler aracın VIN numarasıyla eşleştirilir.'),style:const TextStyle(color:Colors.white54,fontSize:11,height:1.4)));
            }
            final r=rows[vin==null?i-1:i];
            final canRollback=r.canRollback&&vin==r.vin;
            return Card(child:ListTile(
              title:Text(r.moduleName,style:const TextStyle(fontWeight:FontWeight.w700,fontSize:12)),
              subtitle:Text(tx('VIN {0}\nDID {1} • {2}\n{3}\nEski: {4}', [r.vin, r.did, r.status.label, _date(r.createdAt), r.originalHex]),maxLines:5,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:10)),
              trailing:canRollback?FilledButton(onPressed:()=>_rollback(context,r),child:Text(tx('GERİ AL'),style:const TextStyle(fontSize:10))):null,
            ));
          },
        ),
    );
  }

  static String _date(DateTime d){
    final l=d.toLocal();
    String two(int v)=>v.toString().padLeft(2,'0');
    return '${two(l.day)}.${two(l.month)}.${l.year} ${two(l.hour)}:${two(l.minute)}';
  }

  Future<void> _rollback(BuildContext context,CodingBackupRecord r) async{
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text(tx('Eski kod geri yüklensin mi?')),content:Text(tx('{0}\nDID {1}\n\nYalnız bu VIN ve aynı ECU kimliği doğrulanırsa yazılacak.', [r.moduleName, r.did])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:Text(tx('VAZGEÇ'))),FilledButton(onPressed:()=>Navigator.pop(c,true),child:Text(tx('GERİ YÜKLE')))]));
    if(ok!=true||!context.mounted)return;
    final result=await context.read<ObdProvider>().rollbackCodingBackup(r);
    if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(result.message),behavior:SnackBarBehavior.floating));
  }
}
