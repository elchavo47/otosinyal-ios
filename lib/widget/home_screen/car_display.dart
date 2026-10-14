import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:otosinyal_obd2/core/app_colors.dart';
import 'package:otosinyal_obd2/data/brand_assets.dart';
import 'package:otosinyal_obd2/providers/garage_provider.dart';
import 'package:otosinyal_obd2/providers/obd_provider.dart';
import 'package:otosinyal_obd2/l10n/tx.dart';

class CarDisplay extends StatelessWidget {
  const CarDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    final garage = context.watch<GarageProvider>();
    final obd = context.watch<ObdProvider>();
    final vehicle = garage.activeVehicle;
    final brand = vehicle?.brand ?? obd.detectedBrand;
    final logo = brand == null ? null : BrandAssets.logoFor(brand);
    final live = obd.isRealMode;
    final dtcCount = obd.dtcEntries.length;
    final vin = (vehicle?.vin.trim().isNotEmpty == true ? vehicle!.vin.trim() : (obd.detectedVin ?? '')).trim();
    final engineCode = vehicle?.engineCode.trim().isNotEmpty == true ? vehicle!.engineCode.trim() : '--';
    final modelTitle = vehicle?.displayName ?? (obd.detectedBrand == null ? tx('VIN bekleniyor') : tx('{0} • VIN ile algılandı', [obd.detectedBrand]));
    final ecuCount = obd.ecuModules.isNotEmpty ? obd.ecuModules.length : obd.moduleScanResults.values.where((e) => e.discovered).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Theme.of(context).colorScheme.surfaceContainer,
        border: Border.all(color: live ? AppColors.info.withValues(alpha: .28) : Colors.white10),
        boxShadow: [BoxShadow(color: (live ? AppColors.info : Colors.black).withValues(alpha: .08), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 58,
            height: 58,
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .045), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
            child: logo == null ? const Icon(Icons.directions_car_filled_rounded, color: AppColors.info, size: 30) : Image.asset(logo, fit: BoxFit.contain),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(modelTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(vehicle == null ? (live ? tx('Araç profili ECU verileriyle doğrulanıyor') : tx('OBD bağlanınca araç profili otomatik oluşur')) : [if(vehicle.year!=null)'${vehicle.year}', if(vehicle.generation.trim().isNotEmpty) vehicle.generation.trim(), vehicle.fuelType.label].join(' • '), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: 0.48), fontSize: 10.5, fontWeight: FontWeight.w600)),
          ])),
          _LiveBadge(live: live),
        ]),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: .18), borderRadius: BorderRadius.circular(13), border: Border.all(color: Colors.white.withValues(alpha: .055))),
          child: Row(children: [
            const Icon(Icons.fingerprint_rounded, color: Colors.white30, size: 15),
            const SizedBox(width: 7),
            Expanded(child: Text(vin.isEmpty ? tx('VIN okunmadı') : vin, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: .5))),
          ]),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _Info(label: tx('MOTOR KODU'), value: engineCode, color: engineCode=='--'?AppColors.unsupported:AppColors.info)),
          const SizedBox(width: 7),
          Expanded(child: _Info(label: tx('PROTOKOL'), value: obd.protocolName?.isNotEmpty == true ? obd.protocolName! : '--', color: obd.protocolName?.isNotEmpty==true?AppColors.info:AppColors.unsupported)),
          const SizedBox(width: 7),
          Expanded(child: _Info(label: 'ECU', value: ecuCount==0?'--':tx('{0} modül', [ecuCount]), color: ecuCount>0?AppColors.info:AppColors.unsupported)),
        ]),
        const SizedBox(height: 7),
        Row(children: [
          Expanded(child: _Info(label: 'DTC', value: tx('{0} kod', [dtcCount]), color: dtcCount>0?AppColors.danger:AppColors.success)),
          const SizedBox(width: 7),
          Expanded(child: _Info(label: tx('MOTOR DURUMU'), value: obd.milOn == null ? '--' : (obd.milOn! ? tx('Kontrol Gerekli') : tx('Sorun Yok')), color: obd.milOn==true?AppColors.danger:obd.milOn==false?AppColors.success:AppColors.unsupported)),
          const SizedBox(width: 7),
          Expanded(child: _Info(label: tx('BAĞLANTI'), value: live?tx('CANLI'):tx('PASİF'), color: live?AppColors.info:AppColors.unsupported)),
        ]),
      ]),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.live}); final bool live;
  @override Widget build(BuildContext context){final c=live?AppColors.info:AppColors.unsupported;return Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:6),decoration:BoxDecoration(color:c.withValues(alpha:.10),borderRadius:BorderRadius.circular(30),border:Border.all(color:c.withValues(alpha:.38))),child:Row(mainAxisSize:MainAxisSize.min,children:[Container(width:6,height:6,decoration:BoxDecoration(shape:BoxShape.circle,color:c)),const SizedBox(width:5),Text(live?'ECU CANLI':'PASİF',style:TextStyle(color:c,fontSize:8.5,fontWeight:FontWeight.w700))]));}
}

class _Info extends StatelessWidget {
  const _Info({required this.label,required this.value,required this.color}); final String label,value;final Color color;
  @override Widget build(BuildContext context)=>Container(height:57,padding:const EdgeInsets.symmetric(horizontal:9,vertical:8),decoration:BoxDecoration(color:Colors.black.withValues(alpha:.16),borderRadius:BorderRadius.circular(11),border:Border.all(color:color.withValues(alpha:.16))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.center,children:[Text(label,style:const TextStyle(color:Colors.white30,fontSize:6.8,fontWeight:FontWeight.w700,letterSpacing:.3)),const SizedBox(height:4),Text(value,maxLines:2,overflow:TextOverflow.ellipsis,style:TextStyle(color:color,fontSize:9.2,fontWeight:FontWeight.w700))]));
}
