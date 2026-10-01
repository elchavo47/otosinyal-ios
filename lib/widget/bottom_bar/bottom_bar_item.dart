import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:otosinyal_obd2/core/app_colors.dart';
import 'bottom_bar_config.dart';

class BottomBarItem extends StatelessWidget {
  const BottomBarItem({super.key, required this.data, required this.isActive, required this.onTap});
  final BottomBarItemData data;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.accentBright : AppColors.textMuted;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? AppColors.accent.withValues(alpha: .16) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isActive ? AppColors.accent.withValues(alpha: .35) : Colors.transparent),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(data.iconPath, width: isActive ? 25 : 23, height: isActive ? 25 : 23, colorFilter: ColorFilter.mode(color, BlendMode.srcIn)),
              const SizedBox(height: 7),
              Text(data.label, maxLines: 1, overflow: TextOverflow.ellipsis, textScaler: TextScaler.noScaling, style: TextStyle(color: color, fontSize: 12, fontWeight: isActive ? FontWeight.w900 : FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
