import 'package:flutter/material.dart';

class BluetoothWaitingWidget extends StatelessWidget {
  final VoidCallback onActivate;

  const BluetoothWaitingWidget({super.key, required this.onActivate});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bluetooth_searching,
            size: 80,
            color: colorScheme.primary.withValues(alpha: 0.5),
          ),

          const SizedBox(height: 24),
          Text(
            "Bluetooth Bağlantısı",
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            "Gerçek zamanlı araç verilerini görmek için\nOBD2 cihazınızı bağlayın.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 32),

          SizedBox(
            width: 200,
            height: 50,
            child: ElevatedButton(
              onPressed: onActivate,
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: Text(
                "Taramayı Başlat",
                style: TextStyle(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
