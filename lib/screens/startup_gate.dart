import 'dart:async';
import 'package:flutter/material.dart';
import 'package:otosinyal_obd2/core/app_colors.dart';
import 'package:otosinyal_obd2/screens/privacy_consent_screen.dart';
import 'package:otosinyal_obd2/screens/root_screen.dart';
import 'package:otosinyal_obd2/services/privacy_consent_service.dart';
import 'package:otosinyal_obd2/l10n/tx.dart';

class StartupGate extends StatefulWidget {
  const StartupGate({super.key});
  @override State<StartupGate> createState() => _StartupGateState();
}
class _StartupGateState extends State<StartupGate> {
  Widget? _target;
  @override void initState(){ super.initState(); _load(); }
  Future<void> _load() async {
    final results = await Future.wait([PrivacyConsentService.hasAccepted(), Future<void>.delayed(const Duration(milliseconds: 1150))]);
    if(!mounted) return;
    final accepted = results.first as bool;
    setState(()=>_target = accepted ? const RootScreen() : const PrivacyConsentScreen());
  }
  @override Widget build(BuildContext context){
    if(_target != null) return _target!;
    return Scaffold(backgroundColor:AppColors.background,body:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
      Text.rich(TextSpan(children:[TextSpan(text:'OTO',style:TextStyle(color:Colors.white)),TextSpan(text:tx('SİNYAL'),style:TextStyle(color:AppColors.accentBright))]),style:TextStyle(fontSize:38,fontWeight:FontWeight.w900,letterSpacing:-1.7)),
      const SizedBox(height:9),
      const Text('OBD2 DIAGNOSTIC',style:TextStyle(color:Colors.white54,fontSize:10,fontWeight:FontWeight.w700,letterSpacing:3)),
      const SizedBox(height:28),
      const Text('AYD WORKS',style:TextStyle(color:Colors.white54,fontSize:10,fontWeight:FontWeight.w700,letterSpacing:3)),
    ])));
  }
}
