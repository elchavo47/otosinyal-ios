import 'package:flutter/material.dart';
import 'package:otosinyal_obd2/core/app_colors.dart';
import 'package:otosinyal_obd2/widget/bottom_bar/bottom_bar_config.dart';
import 'package:otosinyal_obd2/widget/bottom_bar/bottom_bar_item.dart';
import 'package:otosinyal_obd2/l10n/tx.dart';

class CustomBottomBar extends StatelessWidget {
  const CustomBottomBar({super.key, required this.currentIndex, required this.onItemSelected});

  final int currentIndex;
  final void Function(int index) onItemSelected;

  static const List<BottomBarItemData> _navItems = [
    BottomBarItemData(iconPath: 'assets/images/svg/bottomBar/home.svg', label: tx('Aracım')),
    BottomBarItemData(iconPath: 'assets/images/svg/bottomBar/dashboard.svg', label: tx('Canlı')),
    BottomBarItemData(iconPath: 'assets/images/svg/bottomBar/dtc.svg', label: 'DTC'),
    BottomBarItemData(iconPath: 'assets/images/svg/bottomBar/coding.svg', label: tx('Kodlama')),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      // SafeArea owns the iPhone home-indicator inset; do not clip it.
      padding: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        gradient: AppColors.glassGradient,
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: .08), width: 1)),
        boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: .08), blurRadius: 24, offset: const Offset(0, -8))],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 82,
          child: Row(
          children: List.generate(_navItems.length, (index) {
            return BottomBarItem(
              data: _navItems[index],
              isActive: currentIndex == index,
              onTap: () => onItemSelected(index),
            );
          }),
        ),
        ),
      ),
    );
  }
}
