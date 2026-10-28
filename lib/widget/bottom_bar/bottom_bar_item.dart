import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:otosinyal_obd2/core/app_colors.dart';
import 'bottom_bar_config.dart';

/// Alt menü sekmesi: ikon + kısa etiket. Seçili sekmede ikonun arkasında
/// küçük bir vurgu kapsülü görünür (iOS / Material 3 sekme çubuğu düzeni).
class BottomBarItem extends StatelessWidget {
  const BottomBarItem({super.key, required this.data, required this.isActive, required this.onTap});
  final BottomBarItemData data;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.accentBright : AppColors.textMuted;
    return Expanded(
      child: Semantics(
        selected: isActive,
        button: true,
        label: data.label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: 52,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isActive ? AppColors.accentBright.withValues(alpha: .14) : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SvgPicture.asset(
                  data.iconPath,
                  width: 20,
                  height: 20,
                  colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
