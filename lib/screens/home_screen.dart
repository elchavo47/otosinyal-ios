import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:otosinyal_obd2/core/app_colors.dart';
import 'package:otosinyal_obd2/providers/obd_provider.dart';
import 'package:otosinyal_obd2/providers/connection_mode_provider.dart';
import 'package:otosinyal_obd2/providers/units_provider.dart';
import 'package:otosinyal_obd2/providers/garage_provider.dart';
import 'package:otosinyal_obd2/screens/connect_screen.dart';
import 'package:otosinyal_obd2/services/diagnostic_report_service.dart';
import 'package:otosinyal_obd2/widget/common/oto_ui.dart';
import 'package:otosinyal_obd2/widget/home_screen/car_display.dart';
import 'package:otosinyal_obd2/widget/home_screen/connections_buttons.dart';
import 'package:otosinyal_obd2/widget/home_screen/header_bar.dart';
import 'package:otosinyal_obd2/widget/home_screen/telemetry_card.dart';
import 'package:otosinyal_obd2/screens/car_screen.dart';
import 'package:otosinyal_obd2/screens/performance_test_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  StreamSubscription<String>? _errorSubscription;
  bool _reportBusy=false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ObdProvider>();
      _errorSubscription = provider.errorEvents.listen((message) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: AppColors.danger),
        );
      });
    });
  }

  @override
  void dispose() {
    _errorSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final obd = context.watch<ObdProvider>();
    final units = context.watch<UnitsProvider>();
    final data = obd.data;
    final vehicle=context.watch<GarageProvider>().activeVehicle;
    final speed = units.displaySpeed(data.speed);
    final speedMax = units.isMetric ? 240 : 150;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 18),
          child: Column(
            children: [
              const HeaderBar(),
              const SizedBox(height: 8),
              _ConnectionSummary(obd: obd),
              const SizedBox(height: 10),
              if(!obd.isDeviceConnected)...[
                OtoEmptyState(
                  icon:Icons.cable_rounded,
                  title:'Aracını bağlayalım',
                  body:'OBD adaptörünü seç; OTOSİNYAL VIN’i okuyup aracı ve desteklenen özellikleri otomatik hazırlasın.',
                  actionLabel:'OBD CİHAZINA BAĞLAN',
                  onAction:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>const ConnectionScreen())),
                ),
                const SizedBox(height:10),
              ],
              GestureDetector(
                onTap:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>const CarScreen())),
                child:const CarDisplay(),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 224,
                      child: TelemetryCard(
                        title: 'Hız',
                        value: speed.toDouble(),
                        unit: units.speedUnit,
                        iconPath: 'assets/images/svg/dashboard/speed.svg',
                        progress: (speed / speedMax).clamp(0.0, 1.0),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 224,
                      child: TelemetryCard(
                        title: 'RPM',
                        value: data.rpm.toDouble(),
                        unit: 'rpm',
                        iconPath: 'assets/images/svg/dashboard/engine.svg',
                        progress: (data.rpm / 8000).clamp(0.0, 1.0),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _MiniValue(
                      label: 'SU SICAKLIĞI',
                      value: '${units.displayTemp(data.engineTemp)} ${units.tempUnit}',
                      icon: Icons.thermostat_rounded,
                      alert: data.engineTemp > 110,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: _MiniValue(
                      label: 'AKÜ VOLTAJI',
                      value: '${data.voltage.toStringAsFixed(1)} V',
                      icon: Icons.battery_charging_full_rounded,
                      alert: data.voltage > 0 && (data.voltage < 11.8 || data.voltage > 15),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(
                    child: _MiniValue(
                      label: 'YAĞ SICAKLIĞI',
                      value: obd.oilTempC == null ? '--' : '${obd.oilTempC} °C',
                      icon: Icons.oil_barrel_rounded,
                      alert: obd.oilTempC != null && obd.oilTempC! > 125,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: _MiniValue(
                      label: 'MAP',
                      value: data.boostKpa == null ? '--' : '${data.boostKpa} kPa',
                      icon: Icons.compress_rounded,
                    ),
                  ),
                ],
              ),
              _PerformanceShortcut(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PerformanceTestScreen()),
                ),
              ),
              const SizedBox(height: 8),
              const SizedBox(height: 10),
              ConnectionButtons(
                isConnected: obd.isRealMode,
                isDemoMode: obd.isDemoMode,
                onConnect: () => _toggleReal(context, obd),
                onViewDemo: () {
                  if (obd.isRealMode) {
                    _snack(context, 'Önce ECU bağlantısını kesin');
                    return;
                  }
                  obd.toggleDemoMode();
                },
              ),
              if(obd.isRealMode)...[
                const SizedBox(height:10),
                _ProductActions(
                  obd:obd,
                  reportBusy:_reportBusy,
                  canReport:vehicle!=null,
                  onAdapterTest:obd.isAdapterTesting?null:obd.testAdapterQuality,
                  onReport:vehicle==null||_reportBusy?null:() async {
                    setState(()=>_reportBusy=true);
                    final messenger=ScaffoldMessenger.of(context);
                    try {
                      await obd.runFullVehicleScan();
                      if(mounted)await DiagnosticReportService.createAndShare(vehicle:vehicle!,obd:obd);
                    } catch(error) {
                      messenger.showSnackBar(SnackBar(content:Text('Sağlık raporu oluşturulamadı: $error')));
                    } finally {if(mounted)setState(()=>_reportBusy=false);}
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleReal(BuildContext context, ObdProvider obd) async {
    if (!obd.isDeviceConnected) {
      await Navigator.of(context).push(MaterialPageRoute(builder:(_)=>const ConnectionScreen()));
      return;
    }
    await obd.toggleRealMode();
    if (context.mounted && !obd.isRealMode && !obd.currentConnection.isReconnecting && !obd.isDemoMode) {
      _snack(context, 'ECU ile iletişim kurulamadı');
    }
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.danger),
    );
  }
}

class _PerformanceShortcut extends StatelessWidget {
  const _PerformanceShortcut({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF321014), Color(0xFF160A0C)],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.accentBright.withValues(alpha: .62), width: 1.2),
              boxShadow: [
                BoxShadow(color: AppColors.accentBright.withValues(alpha: .14), blurRadius: 22, offset: const Offset(0, 8)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.accentBright.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.accentBright.withValues(alpha: .32)),
                  ),
                  child: const Icon(Icons.speed_rounded, color: AppColors.accentBright, size: 27),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text('PERFORMANS TESTİ', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: .25)),
                        SizedBox(width: 7),
                        _NewBadge(),
                      ]),
                      SizedBox(height: 4),
                      Text('0-100 • 60-100 • 80-120 • 100-200  |  GPS + OBD', style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w700)),
                      SizedBox(height: 2),
                      Text('Hedefe ulaşınca otomatik durdurur ve kaydeder.', style: TextStyle(color: AppColors.accentBright, fontSize: 11, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 16),
              ],
            ),
          ),
        ),
      );
}

class _NewBadge extends StatelessWidget {
  const _NewBadge();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(color: AppColors.accentBright, borderRadius: BorderRadius.circular(7)),
        child: const Text('YENİ', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: .5)),
      );
}

class _ProductActions extends StatelessWidget {
  const _ProductActions({required this.obd,required this.reportBusy,required this.canReport,required this.onAdapterTest,required this.onReport});
  final ObdProvider obd; final bool reportBusy,canReport; final VoidCallback? onAdapterTest,onReport;
  @override Widget build(BuildContext context){
    final result=obd.adapterQuality;
    final score=result?.score;
    final scoreColor=score==null?AppColors.textMuted:score>=80?AppColors.success:score>=55?AppColors.warning:AppColors.danger;
    return OtoCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[const Icon(Icons.verified_user_rounded,color:AppColors.accentBright,size:20),const SizedBox(width:8),const Expanded(child:Text('ARAÇ SAĞLIK MERKEZİ',style:TextStyle(fontWeight:FontWeight.w700,fontSize:11))),if(score!=null)OtoStatusBadge(label:'ADAPTÖR $score/100',color:scoreColor)]),
      const SizedBox(height:7),
      Text(result==null?'Önce adaptörün hızını, paket kaybını ve uzun UDS desteğini ölç.':result.verdict,style:TextStyle(color:Theme.of(context).colorScheme.onSurfaceVariant,fontSize: 11)),
      const SizedBox(height:11),
      Row(children:[
        Expanded(child:OutlinedButton.icon(onPressed:onAdapterTest,icon:obd.isAdapterTesting?const SizedBox(width:15,height:15,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.speed_rounded,size:17),label:Text(obd.isAdapterTesting?'ÖLÇÜLÜYOR':'ADAPTÖR TESTİ',style:const TextStyle(fontSize: 11,fontWeight:FontWeight.w700)))),
        const SizedBox(width:8),
        Expanded(child:FilledButton.icon(onPressed:onReport,icon:reportBusy?const SizedBox(width:15,height:15,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.health_and_safety_rounded,size:17),label:Text(reportBusy?'TARANIYOR':'SAĞLIK RAPORU',style:const TextStyle(fontSize: 11,fontWeight:FontWeight.w700)))),
      ]),
      if(!canReport)...[const SizedBox(height:7),const Text('PDF için VIN ile oluşturulmuş araç profili bekleniyor.',style:TextStyle(color:AppColors.warning,fontSize: 11))],
    ]));
  }
}


class _ConnectionSummary extends StatelessWidget {
  const _ConnectionSummary({required this.obd});
  final ObdProvider obd;

  @override
  Widget build(BuildContext context) {
    final live = obd.isRealMode;
    final connected = obd.isDeviceConnected;
    final mode = context.watch<ConnectionModeProvider>().mode;
    final transport = switch (mode) {
      ConnectionMode.classic => 'Bluetooth Classic',
      ConnectionMode.ble => 'Bluetooth BLE',
      ConnectionMode.wifi => 'Wi‑Fi TCP',
      ConnectionMode.usb => 'OTG USB',
    };
    final transportIcon = switch (mode) {
      ConnectionMode.classic => Icons.bluetooth_rounded,
      ConnectionMode.ble => Icons.bluetooth_rounded,
      ConnectionMode.wifi => Icons.wifi_rounded,
      ConnectionMode.usb => Icons.usb_rounded,
    };
    final text = live
        ? '$transport: ECU canlı'
        : connected
            ? '$transport: adaptör hazır'
            : '$transport: adaptör bekleniyor';
    final status = live ? 'CANLI' : connected ? 'HAZIR' : 'BAĞLI DEĞİL';

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accentBorder),
      ),
      child: Row(
        children: [
          Icon(
            live ? Icons.link_rounded : transportIcon,
            size: 15,
            color: live ? AppColors.success : AppColors.accentBright,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            status,
            style: TextStyle(
              color: live ? AppColors.success : AppColors.accentBright,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniValue extends StatelessWidget {
  const _MiniValue({required this.label, required this.value, required this.icon, this.alert=false});
  final String label;
  final String value;
  final IconData icon;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: alert ? AppColors.danger : AppColors.accentBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(children:[Icon(icon,color:alert?AppColors.danger:AppColors.accentBright,size:12),const SizedBox(width:5),Expanded(child:Text(label,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white38,fontSize:7.8,fontWeight:FontWeight.w700)))]),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            style: TextStyle(color: alert ? AppColors.danger : Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}


class _DiagnosticsBanner extends StatelessWidget {
  const _DiagnosticsBanner({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: AppColors.vipGradient,
          border: Border.all(color: AppColors.accentBorder),
        ),
        child: const Row(children: [
          ContainerDiagnosticsIcon(),
          SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('AKILLI ARAÇ LAB', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: .4)),
            SizedBox(height: 4),
            Text('Akıllı tarama • canlı analiz • grafikler • teşhis raporu', style: TextStyle(color: Colors.white60, fontSize: 11)),
          ])),
          Icon(Icons.arrow_forward_ios_rounded, color: AppColors.accentBright, size: 16),
        ]),
      ),
    );
  }
}

class ContainerDiagnosticsIcon extends StatelessWidget {
  const ContainerDiagnosticsIcon({super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: 42, height: 42,
    decoration: BoxDecoration(color: AppColors.accentBright.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)),
    child: const Icon(Icons.analytics_rounded, color: AppColors.accentBright),
  );
}
