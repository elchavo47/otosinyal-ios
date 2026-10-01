import 'package:flutter/material.dart';
import 'package:otosinyal_obd2/core/app_colors.dart';

class ConnectionButtons extends StatelessWidget {
  const ConnectionButtons({
    super.key,
    required this.onConnect,
    required this.onViewDemo,
    required this.isConnected,
    required this.isDemoMode,
  });

  final VoidCallback onConnect;
  final VoidCallback onViewDemo;
  final bool isConnected;
  final bool isDemoMode;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 46,
            child: ElevatedButton.icon(
              onPressed: onConnect,
              icon: Icon(isConnected ? Icons.link_rounded : Icons.bluetooth_searching_rounded, size: 18),
              label: Text(isConnected ? 'ECU BAĞLI' : 'ECU’YA BAĞLAN'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentDark,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 46,
          width: 118,
          child: OutlinedButton.icon(
            onPressed: onViewDemo,
            icon: Icon(isDemoMode ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 18),
            label: Text(isDemoMode ? 'KAPAT' : 'DEMO'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accentBright,
              side: const BorderSide(color: AppColors.accentBorder),
              backgroundColor: AppColors.cardBg,
              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }
}
