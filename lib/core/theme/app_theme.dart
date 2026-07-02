import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: AppColors.bg0,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accentA,
      secondary: AppColors.accentB,
      tertiary: AppColors.accentC,
      surface: AppColors.bg1,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: AppColors.textHi, fontWeight: FontWeight.w700),
      displayMedium: TextStyle(color: AppColors.textHi, fontWeight: FontWeight.w700),
      titleLarge: TextStyle(color: AppColors.textHi, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: AppColors.textHi, fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(color: AppColors.textHi),
      bodyMedium: TextStyle(color: AppColors.textLo),
      labelLarge: TextStyle(color: AppColors.textHi, fontWeight: FontWeight.w600),
    ),
    iconTheme: const IconThemeData(color: AppColors.textHi),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: AppColors.textHi,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        fontFamily: 'Inter',
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xF0141B2E),
      contentTextStyle: const TextStyle(
        color: AppColors.textHi,
        fontSize: 13.5,
        fontFamily: 'Inter',
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.glassStroke, width: 1),
      ),
      elevation: 8,
      width: 420,
    ),
  );
}
