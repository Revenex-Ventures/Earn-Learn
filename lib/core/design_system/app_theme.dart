import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

/// Material theme data wired to existing design system tokens.
class AppTheme {
  AppTheme._();

  static final light = ThemeData(
    useMaterial3: true,
    fontFamily: AppTextStyles.fontFamily,
    colorScheme: ColorScheme.light(
      primary: AppColors.forestSoft,
      onPrimary: AppColors.onHeroWarm,
      secondary: AppColors.goldSoftAccent,
      onSecondary: AppColors.inkWarm,
      surface: AppColors.warmSurface,
      onSurface: AppColors.inkWarm,
      error: AppColors.claySoftReject,
      onError: AppColors.warmSurface,
    ),
    scaffoldBackgroundColor: AppColors.warmCanvas,
    canvasColor: AppColors.warmCanvas,
    // Smooth, native-feeling forward/back transitions on every platform
    // (default Material transitions read as slow/desktop-ish on phones).
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.warmCanvas,
      foregroundColor: AppColors.inkWarm,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: AppTextStyles.headlineSmall,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Color(0x00000000),
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.warmSurface,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.warmSurface,
      selectedItemColor: AppColors.forestSoft,
      unselectedItemColor: AppColors.slateWarm,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.warmLine,
      thickness: 1,
      space: 0,
    ),
    textTheme: TextTheme(
      headlineLarge: AppTextStyles.headlineLarge,
      headlineMedium: AppTextStyles.headlineMedium,
      headlineSmall: AppTextStyles.headlineSmall,
      titleLarge: AppTextStyles.titleLarge,
      titleMedium: AppTextStyles.titleMedium,
      titleSmall: AppTextStyles.titleSmall,
      bodyLarge: AppTextStyles.bodyLarge,
      bodyMedium: AppTextStyles.bodyMedium,
      bodySmall: AppTextStyles.bodySmall,
      labelLarge: AppTextStyles.labelLarge,
      labelMedium: AppTextStyles.labelMedium,
      labelSmall: AppTextStyles.labelSmall,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.forestSoft,
        shape: RoundedRectangleBorder(),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.forestSoft,
        foregroundColor: AppColors.onHeroWarm,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.forestSoft,
        side: const BorderSide(color: AppColors.warmLine),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    iconTheme: const IconThemeData(
      color: AppColors.inkWarm,
      size: 24,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: AppColors.warmLine,
  );
}