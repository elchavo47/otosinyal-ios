import 'package:flutter/material.dart';

/// OTOSİNYAL kırmızı metal otomotiv paleti.
/// Nötr gri yüzeyler ve gösterge kırmızısı vurgular.
class AppColors {
  static const Color background = Color(0xFF17181B);
  static const Color surface = Color(0xFF202226);
  static const Color cardBg = Color(0xFF292B30);
  static const Color cardElevated = Color(0xFF33363C);

  static const Color accent = Color(0xFFC51E2C);
  static const Color accentBright = Color(0xFFFF4050);
  static const Color accentDark = Color(0xFF6E1019);
  static const Color accentSoft = Color(0x33D92B3A);
  static const Color accentBorder = Color(0xFF542126);
  static const Color accentCyan = Color(0xFFFF705B);
  static const Color accentPink = Color(0xFFFF6673);
  static const Color accentBlue = Color(0xFFB8AEB0);
  static const Color accentGold = Color(0xFFFBBF24);
  static const Color glass = Color(0x99292B30);

  static const LinearGradient vipGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE12838), Color(0xFF8C1722), Color(0xFF33363C)],
  );

  static const LinearGradient glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xE035383E), Color(0xE0202226)],
  );

  static const Color textMainColor = Colors.white;
  static const Color textMuted = Color(0xFFB7A9AA);
  static const Color accentIconsBottomBar = Colors.white;

  static const Color success = Color(0xFF38D26E);
  static const Color warning = Color(0xFFFFAD32);
  static const Color danger = Color(0xFFFF3D45);
  static const Color info = Color(0xFF5AA9FF);
  static const Color unsupported = Color(0xFF727782);

  // Uygulama geneli semantik durum renkleri: success=sağlıklı, warning=dikkat,
  // danger=hata, info=bilgi/canlı bağlantı, unsupported=desteklenmiyor.
}
