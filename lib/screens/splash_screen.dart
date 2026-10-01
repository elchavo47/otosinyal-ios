import 'package:flutter/material.dart';
import 'startup_gate.dart';
/// Compatibility entry point; the branded startup is owned by StartupGate.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override Widget build(BuildContext context) => const StartupGate();
}
