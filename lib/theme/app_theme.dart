import 'package:flutter/material.dart';

import '../models/media_platform.dart';

class KlipFetchTheme {
  static const Color brandAccent = Color(0xFFFF5A1F);
  static const Color darkBackground = Color(0xFF0E1116);
  static const Color darkSurface = Color(0xFF161B22);
  static const Color darkSurfaceHigh = Color(0xFF1F2630);
  static const Color darkBorder = Color(0xFF2B3442);

  static const Color lightBackground = Color(0xFFF6F7F9);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E6ED);

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: brandAccent,
      brightness: Brightness.dark,
      surface: darkSurface,
    ).copyWith(
      primary: brandAccent,
      onPrimary: Colors.white,
      surface: darkSurface,
      surfaceContainerLow: darkBackground,
      surfaceContainer: darkSurface,
      surfaceContainerHigh: darkSurfaceHigh,
      outlineVariant: darkBorder,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: darkBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurfaceHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: brandAccent, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkSurface,
        indicatorColor: brandAccent.withValues(alpha: 0.2),
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: brandAccent,
      brightness: Brightness.light,
      surface: lightSurface,
    ).copyWith(
      primary: brandAccent,
      onPrimary: Colors.white,
      surface: lightSurface,
      surfaceContainerLow: lightBackground,
      outlineVariant: lightBorder,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: lightBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBackground,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: lightBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: brandAccent, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: lightSurface,
        indicatorColor: brandAccent.withValues(alpha: 0.16),
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  static Color platformColor(MediaPlatform platform) {
    switch (platform) {
      case MediaPlatform.tiktok:
        return const Color(0xFF00C2CB);
      case MediaPlatform.instagram:
        return const Color(0xFFE1306C);
      case MediaPlatform.youtube:
        return const Color(0xFFFF3D3D);
      case MediaPlatform.unsupported:
        return const Color(0xFF8B949E);
    }
  }
}
