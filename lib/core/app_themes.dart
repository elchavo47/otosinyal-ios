import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppThemes {
  static final dayTheme = _buildTheme(
    brightness: Brightness.dark,
    background: const Color(0xFF5B5E63),
    surface: const Color(0xFF666A70),
    card: const Color(0xFF71757B),
    elevated: const Color(0xFF7A7E84),
    muted: const Color(0xFFE0E1E3),
    outline: const Color(0xFF96999E),
  );

  static final darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      onPrimary: Colors.white,
      secondary: AppColors.accentBright,
      onSecondary: Colors.white,
      error: AppColors.danger,
      onError: Colors.white,
      surface: AppColors.background,
      surfaceContainer: AppColors.cardBg,
      surfaceContainerLow: AppColors.surface,
      surfaceContainerHigh: AppColors.cardElevated,
      onSurface: AppColors.textMainColor,
      onSurfaceVariant: AppColors.textMuted,
      outline: AppColors.accentBorder,
      outlineVariant: Color(0xFF321416),
    ),
    dividerColor: const Color(0xFF321416),
    splashColor: AppColors.accentSoft,
    highlightColor: AppColors.accentSoft,
    cardTheme: CardThemeData(
      color: AppColors.cardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: Color(0xFF342021)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.cardElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.accentBorder),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Color(0xFF211012),
      contentTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      behavior: SnackBarBehavior.floating,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.cardBg,
      labelStyle: const TextStyle(color: AppColors.textMuted),
      hintStyle: const TextStyle(color: AppColors.textMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF342021)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF342021)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.3),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 0,
        textStyle: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: .3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.accentBright,
      linearTrackColor: Color(0xFF281315),
      circularTrackColor: Color(0xFF281315),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.cardBg,
      selectedColor: AppColors.accentSoft,
      side: const BorderSide(color: AppColors.accentBorder),
      labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color card,
    required Color elevated,
    required Color muted,
    required Color outline,
  })=>ThemeData(
    useMaterial3:true,
    brightness:brightness,
    fontFamily:'Inter',
    scaffoldBackgroundColor:background,
    appBarTheme:AppBarTheme(backgroundColor:background,foregroundColor:Colors.white,elevation:0),
    colorScheme:ColorScheme.dark(
      primary:AppColors.accent,
      secondary:AppColors.accentBright,
      error:AppColors.danger,
      surface:background,
      surfaceContainer:card,
      surfaceContainerLow:surface,
      surfaceContainerHigh:elevated,
      onSurface:Colors.white,
      onSurfaceVariant:muted,
      outline:outline,
      outlineVariant:outline.withValues(alpha:.55),
    ),
    dividerColor:outline.withValues(alpha:.65),
    cardTheme:CardThemeData(color:card,elevation:0,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14),side:BorderSide(color:outline))),
    dialogTheme:DialogThemeData(backgroundColor:elevated,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18),side:const BorderSide(color:AppColors.accentBorder))),
    snackBarTheme:SnackBarThemeData(backgroundColor:const Color(0xFF3D4045),contentTextStyle:const TextStyle(color:Colors.white,fontWeight:FontWeight.w700),behavior:SnackBarBehavior.floating),
    inputDecorationTheme:InputDecorationTheme(filled:true,fillColor:card,labelStyle:TextStyle(color:muted),hintStyle:TextStyle(color:muted),border:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:BorderSide(color:outline)),enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:BorderSide(color:outline)),focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:const BorderSide(color:AppColors.accent,width:1.3))),
    elevatedButtonTheme:ElevatedButtonThemeData(style:ElevatedButton.styleFrom(backgroundColor:AppColors.accent,foregroundColor:Colors.white,elevation:0,textStyle:const TextStyle(fontWeight:FontWeight.w900,letterSpacing:.3),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12)))),
    progressIndicatorTheme:const ProgressIndicatorThemeData(color:AppColors.accentBright),
    chipTheme:ChipThemeData(backgroundColor:card,selectedColor:AppColors.accentSoft,side:BorderSide(color:outline),labelStyle:const TextStyle(color:Colors.white,fontWeight:FontWeight.w700),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14))),
  );
}
