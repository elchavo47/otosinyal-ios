import 'package:flutter/material.dart';
import 'package:otosinyal_obd2/core/app_colors.dart';
import 'package:otosinyal_obd2/screens/settings_screen.dart';

class HeaderBar extends StatelessWidget {
  const HeaderBar({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          _HeaderIconButton(
            icon: Icons.menu_rounded,
            onTap: () => showSettingsSheet(context),
          ),
          const Expanded(child: _Wordmark()),
          _HeaderIconButton(
            icon: Icons.notifications_none_rounded,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Yeni bildirim yok')),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        RichText(
          textScaler: TextScaler.noScaling,
          text: const TextSpan(
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 22,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              letterSpacing: -1,
            ),
            children: [
              TextSpan(text: 'OTO', style: TextStyle(color: Colors.white)),
              TextSpan(text: 'SİNYAL', style: TextStyle(color: AppColors.accentBright)),
            ],
          ),
        ),
        const SizedBox(height: 1),
        const Text(
          'OBD2 DIAGNOSTIC',
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 7.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Icon(icon, color: Colors.white, size: 23),
        ),
      ),
    );
  }
}
