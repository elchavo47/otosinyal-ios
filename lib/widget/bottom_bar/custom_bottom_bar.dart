import 'package:flutter/material.dart';
import 'package:otosinyal_obd2/core/app_colors.dart';
import 'package:otosinyal_obd2/widget/bottom_bar/bottom_bar_config.dart';
import 'package:otosinyal_obd2/widget/bottom_bar/bottom_bar_item.dart';
import 'package:otosinyal_obd2/l10n/tx.dart';

class CustomBottomBar extends StatelessWidget {
  const CustomBottomBar({super.key, required this.currentIndex, required this.onItemSelected, this.showCoding = false});

  final int currentIndex;
  final void Function(int index) onItemSelected;

  /// Kodlama sekmesi yalnız uyumlu araç + adaptör bağlıyken gösterilir.
  final bool showCoding;

  // Getter: dil değişince etiketler yeniden çevrilir.
  static List<BottomBarItemData> get _allItems => [
    BottomBarItemData(iconPath: 'assets/images/svg/bottomBar/home.svg', label: tx('Aracım')),
    BottomBarItemData(iconPath: 'assets/images/svg/bottomBar/dashboard.svg', label: tx('Canlı')),
    BottomBarItemData(iconPath: 'assets/images/svg/bottomBar/dtc.svg', label: 'DTC'),
    BottomBarItemData(iconPath: 'assets/images/svg/bottomBar/coding.svg', label: tx('Kodlama')),
  ];

  @override
  Widget build(BuildContext context) {
    final all = _allItems;
    final navItems = showCoding ? all : all.sublist(0, 3);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: .06), width: .5)),
      ),
      child: SafeArea(
        top: false,
        // SafeArea owns the iPhone home-indicator inset; do not clip it.
        child: SizedBox(
          height: 56,
          child: Row(
            children: List.generate(navItems.length, (index) {
              return BottomBarItem(
                data: navItems[index],
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
