import 'package:flutter/material.dart';

import '../models/media_platform.dart';
import '../models/media_probe.dart';

class BadgeTone {
  const BadgeTone({
    required this.ink,
    required this.fill,
    required this.border,
  });

  final Color ink;
  final Color fill;
  final Color border;
}

class KlipFetchTheme {
  static const Color brandAccent = Color(0xFFBF3909);
  static const Color darkBackground = Color(0xFF0E1116);
  static const Color darkSurface = Color(0xFF161B22);
  static const Color darkSurfaceHigh = Color(0xFF1F2630);
  static const Color darkBorder = Color(0xFF2B3442);

  static const Color lightBackground = Color(0xFFF5F2EC);
  static const Color lightSurface = Color(0xFFFFFCF7);
  static const Color lightSurfaceSubtle = Color(0xFFEFECE4);
  static const Color lightSurfaceHigh = Color(0xFFE8E2D7);
  static const Color lightBorder = Color(0xFFE4DDD3);
  static const Color lightControlOutline = Color(0xFF8A8175);
  static const Color lightInk = Color(0xFF1B1816);
  static const Color lightMutedInk = Color(0xFF5F5852);
  static const Color lightOnPrimary = Color(0xFFFFFDF9);
  static const Color lightTonalFill = Color(0xFFFFE3D6);
  static const Color lightOnTonal = Color(0xFF7D2605);
  static const Color lightError = Color(0xFFBA1A1A);
  static const Color lightErrorFill = Color(0xFFFCE8E8);
  static const Color lightErrorBorder = Color(0xFFE6B3B3);

  static const BadgeTone successTone = BadgeTone(
    ink: Color(0xFF166E36),
    fill: Color(0xFFE4F4EA),
    border: Color(0xFFA9D9BB),
  );
  static const BadgeTone warningTone = BadgeTone(
    ink: Color(0xFF8A5300),
    fill: Color(0xFFFCF1DB),
    border: Color(0xFFE6CB94),
  );
  static const BadgeTone neutralTone = BadgeTone(
    ink: Color(0xFF4A4540),
    fill: Color(0xFFEDE9E2),
    border: Color(0xFFCEC7BC),
  );
  static const BadgeTone errorTone = BadgeTone(
    ink: lightError,
    fill: lightErrorFill,
    border: lightErrorBorder,
  );

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
      onPrimary: lightOnPrimary,
      primaryContainer: lightTonalFill,
      onPrimaryContainer: lightOnTonal,
      secondaryContainer: lightTonalFill,
      onSecondaryContainer: lightOnTonal,
      surface: lightSurface,
      onSurface: lightInk,
      onSurfaceVariant: lightMutedInk,
      surfaceContainerLowest: lightSurface,
      surfaceContainerLow: lightBackground,
      surfaceContainer: lightSurfaceSubtle,
      surfaceContainerHigh: lightSurfaceHigh,
      outline: lightControlOutline,
      outlineVariant: lightBorder,
      error: lightError,
      onError: lightOnPrimary,
      errorContainer: lightErrorFill,
      onErrorContainer: const Color(0xFF690005),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: lightBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBackground,
        foregroundColor: lightInk,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        surfaceTintColor: Colors.transparent,
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
          borderSide: const BorderSide(color: lightControlOutline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightControlOutline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: brandAccent, width: 1.8),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          side: WidgetStateProperty.all(
            const BorderSide(color: lightControlOutline),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? lightTonalFill
                : lightSurface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected) ? lightOnTonal : lightInk,
          ),
          iconColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected) ? lightOnTonal : lightInk,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: lightSurface,
        selectedColor: lightTonalFill,
        checkmarkColor: lightOnTonal,
        surfaceTintColor: Colors.transparent,
        side: WidgetStateBorderSide.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? BorderSide(color: brandAccent.withValues(alpha: 0.4))
              : const BorderSide(color: lightControlOutline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brandAccent,
          foregroundColor: lightOnPrimary,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: brandAccent,
          side: const BorderSide(color: lightControlOutline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: brandAccent),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? lightOnPrimary : lightMutedInk,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? brandAccent : lightSurfaceSubtle,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.transparent
              : lightControlOutline,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: brandAccent,
        linearTrackColor: Color(0xFFE8DED3),
      ),
      dividerTheme: const DividerThemeData(
        color: lightBorder,
        thickness: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: lightSurface,
        indicatorColor: lightTonalFill,
        surfaceTintColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? lightOnTonal
                : lightMutedInk,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? lightInk
                : lightMutedInk,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  static BadgeTone platformTone(MediaPlatform platform) {
    switch (platform) {
      case MediaPlatform.tiktok:
        return const BadgeTone(
          ink: Color(0xFF006E75),
          fill: Color(0xFFE4F5F6),
          border: Color(0xFF9ED6DA),
        );
      case MediaPlatform.instagram:
        return const BadgeTone(
          ink: Color(0xFFB81D53),
          fill: Color(0xFFFBE9EF),
          border: Color(0xFFE8B4C6),
        );
      case MediaPlatform.youtube:
        return const BadgeTone(
          ink: Color(0xFFC41E1E),
          fill: Color(0xFFFCEAEA),
          border: Color(0xFFECB8B8),
        );
      case MediaPlatform.unsupported:
        return neutralTone;
    }
  }

  static BadgeTone engineTone(DownloadEngine engine, {bool usedFallback = false}) {
    if (engine == DownloadEngine.rustCore) {
      return const BadgeTone(
        ink: Color(0xFFB03A1B),
        fill: Color(0xFFFBEAE5),
        border: Color(0xFFE8BBAE),
      );
    }
    if (usedFallback) {
      return warningTone;
    }
    return const BadgeTone(
      ink: Color(0xFFA12F06),
      fill: Color(0xFFFDECE4),
      border: Color(0xFFE8B8A4),
    );
  }

  static Color platformColor(MediaPlatform platform) =>
      platformTone(platform).ink;
}
