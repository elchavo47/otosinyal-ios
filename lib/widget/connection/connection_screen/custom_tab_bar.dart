import 'package:flutter/material.dart';
import 'package:otosinyal_obd2/core/app_colors.dart';

enum ConnectionTab { bluetooth, wifi, usb }

class CustomTabBar extends StatelessWidget {
  const CustomTabBar({super.key, required this.selectedTab, required this.onTabSelected});
  final ConnectionTab selectedTab;
  final ValueChanged<ConnectionTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 39,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.accentBorder)),
      ),
      child: Row(
        children: ConnectionTab.values.map((tab) {
          final active = selectedTab == tab;
          final label = switch (tab) {
            ConnectionTab.bluetooth => 'BLUETOOTH',
            ConnectionTab.wifi => 'WIFI',
            ConnectionTab.usb => 'USB',
          };
          return Expanded(
            child: InkWell(
              onTap: () => onTabSelected(tab),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: active ? AppColors.accentBright : Colors.transparent, width: 2)),
                ),
                child: Text(
                  label,
                  style: TextStyle(color: active ? AppColors.accentBright : Colors.white54, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: .5),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
