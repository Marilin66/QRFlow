import 'package:flutter/material.dart';

/// Tokens du système de design QRFlow.
///
/// La palette est fixée par le cahier des charges : bleu-violet technologique
/// (#5B5FEF), vert de confirmation (#2FB380), rouge d'alerte (#E2574C) et
/// fonds neutres #F7F8FC (clair) / #12131A (sombre). La typographie est un
/// choix délibéré du skill frontend-design : Space Grotesk pour la marque et
/// les titres, Inter pour l'interface, monospace pour le contenu décodé.
abstract final class QrTokens {
  // ── Palette de marque (spécifiée) ────────────────────────────────────
  static const Color primary = Color(0xFF5B5FEF);
  static const Color success = Color(0xFF2FB380);
  static const Color alert = Color(0xFFE2574C);
  static const Color bgLight = Color(0xFFF7F8FC);
  static const Color bgDark = Color(0xFF12131A);

  // ── Surfaces, textes et bordures (dérivés) ───────────────────────────
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1B1C26);
  static const Color textLight = Color(0xFF1C1D2E);
  static const Color textDark = Color(0xFFF2F3FA);
  static const Color mutedLight = Color(0xFF6B6E85);
  static const Color mutedDark = Color(0xFF9A9DB4);
  static const Color borderLight = Color(0xFFE4E6F2);
  static const Color borderDark = Color(0xFF2A2C3C);

  static const Color primaryContainerLight = Color(0xFFE9E9FF);
  static const Color primaryContainerDark = Color(0xFF2A2B5E);
  static const Color successContainerLight = Color(0xFFDDF5EA);
  static const Color successContainerDark = Color(0xFF16372B);
  static const Color alertContainerLight = Color(0xFFFBE3E1);
  static const Color alertContainerDark = Color(0xFF3E1F1B);

  // ── Typographie ──────────────────────────────────────────────────────
  static const String displayFamily = 'SpaceGrotesk'; // Marque & titres
  static const String bodyFamily = 'Inter'; // Interface
  static const String monoFamily = 'monospace'; // Contenu décodé brut

  // ── Géométrie ────────────────────────────────────────────────────────
  static const double radiusCard = 20;
  static const double radiusField = 14;
  static const double radiusPill = 999;
}

/// Construit le thème QRFlow pour une luminosité donnée.
ThemeData buildTheme(Brightness brightness) {
  final bool dark = brightness == Brightness.dark;

  final ColorScheme scheme = ColorScheme(
    brightness: brightness,
    primary: QrTokens.primary,
    onPrimary: Colors.white,
    primaryContainer: dark ? QrTokens.primaryContainerDark : QrTokens.primaryContainerLight,
    onPrimaryContainer: dark ? const Color(0xFFE0E0FF) : const Color(0xFF23245C),
    secondary: QrTokens.success,
    onSecondary: Colors.white,
    secondaryContainer: dark ? QrTokens.successContainerDark : QrTokens.successContainerLight,
    onSecondaryContainer: dark ? const Color(0xFFBFEBD9) : const Color(0xFF0E3D2E),
    error: QrTokens.alert,
    onError: Colors.white,
    errorContainer: dark ? QrTokens.alertContainerDark : QrTokens.alertContainerLight,
    onErrorContainer: dark ? const Color(0xFFF5C6C2) : const Color(0xFF5A1F19),
    surface: dark ? QrTokens.surfaceDark : QrTokens.surfaceLight,
    onSurface: dark ? QrTokens.textDark : QrTokens.textLight,
    surfaceContainerHighest: dark ? QrTokens.borderDark : QrTokens.borderLight,
    onSurfaceVariant: dark ? QrTokens.mutedDark : QrTokens.mutedLight,
    outline: dark ? QrTokens.borderDark : QrTokens.borderLight,
    outlineVariant: dark ? QrTokens.borderDark : QrTokens.borderLight,
    surfaceTint: Colors.transparent,
  );

  final TextTheme base =
      dark ? Typography.material2021().white : Typography.material2021().black;

  final TextTheme text = base
      .apply(
        fontFamily: QrTokens.bodyFamily,
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      )
      .copyWith(
        displayLarge: base.displayLarge?.copyWith(
          fontFamily: QrTokens.displayFamily,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.5,
        ),
        displayMedium: base.displayMedium?.copyWith(
          fontFamily: QrTokens.displayFamily,
          fontWeight: FontWeight.w700,
          letterSpacing: -1,
        ),
        displaySmall: base.displaySmall?.copyWith(
          fontFamily: QrTokens.displayFamily,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineLarge: base.headlineLarge?.copyWith(
          fontFamily: QrTokens.displayFamily,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineMedium: base.headlineMedium?.copyWith(
          fontFamily: QrTokens.displayFamily,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: base.titleLarge?.copyWith(
          fontFamily: QrTokens.displayFamily,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      );

  final OutlineInputBorder fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(QrTokens.radiusField),
    borderSide: BorderSide(color: scheme.outlineVariant),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? QrTokens.bgDark : QrTokens.bgLight,
    canvasColor: scheme.surface,
    textTheme: text,
    fontFamily: QrTokens.bodyFamily,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(QrTokens.radiusCard),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(QrTokens.radiusPill),
        ),
        textStyle: const TextStyle(
          fontFamily: QrTokens.bodyFamily,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.primary,
        side: BorderSide(color: scheme.outlineVariant, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(QrTokens.radiusPill),
        ),
        textStyle: const TextStyle(
          fontFamily: QrTokens.bodyFamily,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(QrTokens.radiusField),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
  );
}
