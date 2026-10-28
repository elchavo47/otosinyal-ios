import 'package:flutter/material.dart';

/// OTOSİNYAL paleti.
/// Göz yormaması için nötr koyu gri yüzeyler, yumuşatılmış kırmızı vurgu ve
/// doygunluğu düşürülmüş durum renkleri kullanılır. Kırmızı yalnız vurgu içindir.
class AppColors {
  static const Color background = Color(0xFF141518);
  static const Color surface = Color(0xFF1C1D21);
  static const Color cardBg = Color(0xFF212328);
  static const Color cardElevated = Color(0xFF2B2D33);

  static const Color accent = Color(0xFFB8232F);
  static const Color accentBright = Color(0xFFF0646C);
  static const Color accentDark = Color(0xFF5A1A20);
  static const Color accentSoft = Color(0x26E0525B);
  static const Color accentBorder = Color(0xFF34363C);
  static const Color accentCyan = Color(0xFFFF705B);
  static const Color accentPink = Color(0xFFFF6673);
  static const Color accentBlue = Color(0xFFB8AEB0);
  static const Color accentGold = Color(0xFFFBBF24);
  static const Color glass = Color(0x99292B30);

  static const LinearGradient vipGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFB8232F), Color(0xFF6E1A22), Color(0xFF2B2D33)],
  );

  static const LinearGradient glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xF01C1D21), Color(0xF01C1D21)],
  );

  static const Color textMainColor = Colors.white;
  static const Color textMuted = Color(0xFFA7ABB3);
  static const Color accentIconsBottomBar = Colors.white;

  static const Color success = Color(0xFF4CC97A);
  static const Color warning = Color(0xFFF2B04C);
  static const Color danger = Color(0xFFEE5A61);
  static const Color info = Color(0xFF6AAEF5);
  static const Color unsupported = Color(0xFF727782);

  // Uygulama geneli semantik durum renkleri: success=sağlıklı, warning=dikkat,
  // danger=hata, info=bilgi/canlı bağlantı, unsupported=desteklenmiyor.
}
