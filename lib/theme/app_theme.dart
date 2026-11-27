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
  static const String displayFontFamily = 'BricolageGrotesque';
  static const String bodyFontFamily = 'IBMPlexSans';
  static const String monoFontFamily = 'IBMPlexMono';

  static const Color brandAccent = Color(0xFFBF3909);
  static const Color darkBackground = Color(0xFF0E1116);
  static const Color darkSurface = Color(0xFF161B22);
  static const Color darkSurfaceHigh = Color(0xFF1F2630);
  static const Color darkBorder = Color(0xFF2B3442);

  static const Color lightBackground = Color(0xFFF5F2EC);
  static const Color lightSurface = Color(0xFFFFFCF7);
  static const Color lightSurfaceSubtle = Color(0xFFECE7DD);
  static const Color lightSurfaceHigh = Color(0xFFE2DBD0);
  static const Color lightBorder = Color(0xFFD8D0C4);
  static const Color lightControlOutline = Color(0xFF877D71);
  static const Color lightInk = Color(0xFF1A1715);
  static const Color inkSecondary = Color(0xFF4A433C);
  static const Color lightMutedInk = Color(0xFF6B635B);
  static const Color lightOnPrimary = Color(0xFFFFFDF9);
  static const Color lightTonalFill = Color(0xFFF8E5DC);
  static const Color lightOnTonal = Color(0xFF7D2605);
  static const Color lightError = Color(0xFFB81D1D);
  static const Color lightErrorFill = Color(0xFFFBE8E8);
  static const Color lightErrorBorder = Color(0xFFDFB2B2);

  static const BadgeTone successTone = BadgeTone(
    ink: Color(0xFF166835),
    fill: Color(0xFFE4F2E8),
    border: Color(0xFFB6DBBF),
  );
  static const BadgeTone warningTone = BadgeTone(
    ink: Color(0xFF8C5200),
    fill: Color(0xFFFAF0DA),
    border: Color(0xFFE5CCA0),
  );
  static const BadgeTone neutralTone = BadgeTone(
    ink: inkSecondary,
    fill: lightSurfaceSubtle,
    border: lightBorder,
  );
  static const BadgeTone errorTone = BadgeTone(
    ink: lightError,
    fill: lightErrorFill,
    border: lightErrorBorder,
  );

  static TextStyle displayStyle({
    double size = 26,
    double wdth = 75,
    double height = 1.08,
    double letterSpacing = -0.4,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: displayFontFamily,
      fontSize: size,
      height: height,
      letterSpacing: letterSpacing,
      fontWeight: FontWeight.w800,
      color: color ?? lightInk,
      fontVariations: [
        FontVariation('wdth', wdth),
        const FontVariation('wght', 800),
        FontVariation('opsz', size >= 24 ? 96 : 48),
      ],
    );
  }

  static TextStyle monoStyle({
    double size = 12,
    Color? color,
    double height = 1.35,
  }) {
    return TextStyle(
      fontFamily: monoFontFamily,
      fontSize: size,
      height: height,
      fontWeight: FontWeight.w400,
      color: color ?? inkSecondary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

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
      fontFamily: bodyFontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: darkBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
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
      secondary: lightInk,
      onSecondary: lightOnPrimary,
      secondaryContainer: lightSurfaceSubtle,
      onSecondaryContainer: lightInk,
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

    const textTheme = TextTheme(
      titleLarge: TextStyle(
        fontFamily: bodyFontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: lightInk,
      ),
      titleMedium: TextStyle(
        fontFamily: bodyFontFamily,
        fontSize: 15,
        height: 1.33,
        fontWeight: FontWeight.w600,
        color: lightInk,
      ),
      bodyLarge: TextStyle(
        fontFamily: bodyFontFamily,
        fontSize: 14,
        height: 1.43,
        fontWeight: FontWeight.w400,
        color: lightInk,
      ),
      bodyMedium: TextStyle(
        fontFamily: bodyFontFamily,
        fontSize: 13.5,
        height: 1.42,
        fontWeight: FontWeight.w400,
        color: lightInk,
      ),
      bodySmall: TextStyle(
        fontFamily: bodyFontFamily,
        fontSize: 12,
        height: 1.33,
        fontWeight: FontWeight.w400,
        color: lightMutedInk,
      ),
      labelLarge: TextStyle(
        fontFamily: bodyFontFamily,
        fontSize: 13,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: lightInk,
      ),
      labelMedium: TextStyle(
        fontFamily: bodyFontFamily,
        fontSize: 12,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: lightInk,
      ),
      labelSmall: TextStyle(
        fontFamily: bodyFontFamily,
        fontSize: 11,
        height: 1.25,
        fontWeight: FontWeight.w600,
        color: lightMutedInk,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: bodyFontFamily,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: lightBackground,
      splashFactory: NoSplash.splashFactory,
      highlightColor: lightSurfaceHigh.withValues(alpha: 0.45),
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
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: lightBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        hintStyle: monoStyle(size: 12, color: lightMutedInk),
        labelStyle: const TextStyle(
          fontFamily: bodyFontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: lightInk,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: lightControlOutline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: lightControlOutline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: brandAccent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: lightError),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: lightError, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brandAccent,
          foregroundColor: lightOnPrimary,
          disabledBackgroundColor: lightSurfaceSubtle,
          disabledForegroundColor: lightMutedInk,
          elevation: 0,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          textStyle: const TextStyle(
            fontFamily: bodyFontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: lightSurface,
          foregroundColor: lightInk,
          disabledBackgroundColor: lightSurfaceSubtle,
          disabledForegroundColor: lightMutedInk,
          elevation: 0,
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          side: const BorderSide(color: lightInk),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          textStyle: const TextStyle(
            fontFamily: bodyFontFamily,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: lightInk,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          textStyle: const TextStyle(
            fontFamily: bodyFontFamily,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: brandAccent,
        linearTrackColor: lightSurfaceSubtle,
        borderRadius: BorderRadius.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: lightBorder,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: lightSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: lightControlOutline),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: lightInk,
        contentTextStyle: const TextStyle(
          fontFamily: bodyFontFamily,
          fontSize: 13,
          color: lightOnPrimary,
        ),
        actionTextColor: lightTonalFill,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  static BadgeTone platformTone(MediaPlatform platform) {
    switch (platform) {
      case MediaPlatform.tiktok:
        return const BadgeTone(
          ink: Color(0xFF006B72),
          fill: Color(0xFFE4F4F5),
          border: Color(0xFFB2DCDF),
        );
      case MediaPlatform.instagram:
        return const BadgeTone(
          ink: Color(0xFFB31E52),
          fill: Color(0xFFFBE9EF),
          border: Color(0xFFE8B4C6),
        );
      case MediaPlatform.youtube:
        return const BadgeTone(
          ink: Color(0xFFC41E1E),
          fill: Color(0xFFFBEAEA),
          border: Color(0xFFEBB8B8),
        );
      case MediaPlatform.unsupported:
        return neutralTone;
    }
  }

  static BadgeTone engineTone(DownloadEngine engine, {bool usedFallback = false}) {
    if (engine == DownloadEngine.ytDlp && usedFallback) {
      return warningTone;
    }
    return neutralTone;
  }

  static Color platformColor(MediaPlatform platform) =>
      platformTone(platform).ink;
}
