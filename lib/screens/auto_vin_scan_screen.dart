import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../data/brand_assets.dart';
import '../providers/obd_provider.dart';
import 'package:otosinyal_obd2/l10n/tx.dart';

class AutoVinScanOverlay extends StatefulWidget {
  const AutoVinScanOverlay({super.key});

  @override
  State<AutoVinScanOverlay> createState() => _AutoVinScanOverlayState();
}

class _AutoVinScanOverlayState extends State<AutoVinScanOverlay> {

  @override
  Widget build(BuildContext context) {
    final obd = context.watch<ObdProvider>();
    final vin = obd.detectedVin;
    final brand = obd.detectedBrand;
    final logo = brand == null ? null : BrandAssets.logoFor(brand);

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Theme.of(context).colorScheme.surfaceContainerHigh,Theme.of(context).scaffoldBackgroundColor,Theme.of(context).colorScheme.surfaceContainerLow],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.speed_rounded, color: AppColors.accentBright, size: 54),
                  const SizedBox(height: 18),
                  Text(
                    tx('OTOSİNYAL'),
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2.2),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    vin == null ? tx('ARAÇ KİMLİĞİ TARANIYOR') : tx('ARAÇ KİMLİĞİ DOĞRULANDI'),
                    style: const TextStyle(color: AppColors.accentBright, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.4),
                  ),
                  const SizedBox(height: 28),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: vin == null
                        ? const _RollingVinLine()
                        : _DetectedVehicle(vin: vin, brand: brand, logo: logo),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    obd.initMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: 230,
                    child: LinearProgressIndicator(
                      minHeight: 4,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation(AppColors.accentBright),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    tx('Garaj seçimi gerekmiyor • VIN üzerinden otomatik tanıma'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RollingVinLine extends StatefulWidget {
  const _RollingVinLine();

  @override
  State<_RollingVinLine> createState()=>_RollingVinLineState();
}

class _RollingVinLineState extends State<_RollingVinLine> {
  static const chars='ABCDEFGHJKLMNPRSTUVWXYZ0123456789';
  final _random=Random();
  late String _rolling;
  Timer? _timer;

  String _next()=>List.generate(17,(_)=>chars[_random.nextInt(chars.length)]).join();

  @override
  void initState(){
    super.initState();
    _rolling=_next();
    _timer=Timer.periodic(const Duration(milliseconds:32),(_){if(mounted)setState(()=>_rolling=_next());});
  }

  @override
  void dispose(){_timer?.cancel();super.dispose();}

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(child:Container(
          key: const ValueKey('rolling-vin'),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: .35), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.accentBorder)),
          child: Text(_rolling,maxLines:1,overflow:TextOverflow.clip,textAlign:TextAlign.center,style:const TextStyle(color:Colors.white,fontSize:15,fontWeight:FontWeight.w900,letterSpacing:2.5)),
        ));
  }
}

class _DetectedVehicle extends StatelessWidget {
  const _DetectedVehicle({required this.vin, required this.brand, required this.logo});
  final String vin;
  final String? brand;
  final String? logo;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('detected-vin'),
      children: [
        // VIN bulunduğunda animasyon ile marka logosunu aynı Stack içinde
        // bindirmiyoruz. Küçük ekranlarda ve bazı Lottie kompozisyonlarında logo
        // animasyonun üstüne oturuyordu; artık iki ayrı, sabit alan var.
        SizedBox(
          width: 170,
          height: 92,
          child: Lottie.asset(
            'assets/animations/obd_installation.json',
            repeat: true,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: 82,
          height: 82,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .94),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.accentBright, width: 2),
            boxShadow: const [
              BoxShadow(color: Colors.black38, blurRadius: 18, offset: Offset(0, 8)),
            ],
          ),
          child: logo == null
              ? const Icon(Icons.directions_car_filled_rounded, color: AppColors.accent, size: 44)
              : Image.asset(logo!, fit: BoxFit.contain),
        ),
        const SizedBox(height: 14),
        Text(brand ?? tx('MARKA TANINAMADI'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(vin, style: const TextStyle(color: AppColors.accentBright, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.8)),
      ],
    );
  }
}
