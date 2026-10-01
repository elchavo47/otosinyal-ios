import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:otosinyal_obd2/providers/obd_provider.dart';
import 'package:otosinyal_obd2/screens/auto_vin_scan_screen.dart';
import 'package:otosinyal_obd2/screens/advanced_diagnostics_screen.dart';
import 'package:otosinyal_obd2/screens/coding_screen.dart';
import 'package:otosinyal_obd2/screens/dtc_screen.dart';
import 'package:otosinyal_obd2/widget/bottom_bar/custom_bottom_bar.dart';
import 'home_screen.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _currentIndex = 0;
  bool _autoAttempted = false;
  bool _showAutoVin = false;

  late final List<Widget> _screens = [
    const HomeScreen(),
    const AdvancedDiagnosticsScreen(),
    const DtcScreen(),
    const CodingScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<ObdProvider>(
      builder: (context, obd, _) {
        _scheduleAutomaticVinScan(obd);
        return Stack(
          children: [
            Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              body: IndexedStack(index: _currentIndex, children: _screens),
              bottomNavigationBar: CustomBottomBar(
                currentIndex: _currentIndex,
                onItemSelected: _selectTab,
              ),
            ),
            if (_showAutoVin || obd.state == ObdConnectionState.initializing)
              const Positioned.fill(child: AutoVinScanOverlay()),
          ],
        );
      },
    );
  }

  // Browsing coding history and reading ECU values must not trigger a write warning.
  // Write operations retain their own confirmation and backup checks.
  void _selectTab(int index) {
    if (mounted) setState(() => _currentIndex = index);
  }

  void _scheduleAutomaticVinScan(ObdProvider obd) {
    if (!obd.isDeviceConnected) {
      if (_autoAttempted && obd.state == ObdConnectionState.disconnected) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _autoAttempted = false);
        });
      }
      return;
    }
    if (_autoAttempted || obd.isRealMode || obd.state == ObdConnectionState.initializing) return;
    _autoAttempted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _showAutoVin = true);
      unawaited(_startAutomaticVinScan(obd));
    });
  }

  Future<void> _startAutomaticVinScan(ObdProvider obd) async {
    await obd.toggleRealMode();
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (mounted) setState(() => _showAutoVin = false);
  }
}
