import 'package:flutter/material.dart';

import 'config.dart';

/// Couleurs de marque, identiques en mode clair et sombre.
class AppColors {
  static const blue = AppConfig.blue;
  static const red = AppConfig.red;
  static const live = Color(0xFFFF2D2D);
}

/// Couleurs neutres qui changent avec le thème. Lues via `context.palette`.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.outline,
    required this.text,
    required this.textMuted,
    required this.accent,
  });

  final Color background;
  final Color surface;
  final Color surfaceHigh;
  final Color outline;
  final Color text;
  final Color textMuted;

  /// Couleur des éléments interactifs : le bleu de la marque, éclairci en mode sombre.
  final Color accent;

  /// Palette « plateau TV » construite autour du bleu et du rouge de la marque.
  static const dark = AppPalette(
    background: Color(0xFF0E0C1D),
    surface: Color(0xFF18152E),
    surfaceHigh: Color(0xFF231F40),
    outline: Color(0xFF2F2A52),
    text: Colors.white,
    textMuted: Color(0xFFA9A6C2),
    accent: Color(0xFF7B61FF),
  );

  static const light = AppPalette(
    background: Color(0xFFF5F4FA),
    surface: Colors.white,
    surfaceHigh: Color(0xFFECEAF5),
    outline: Color(0xFFE1DEEE),
    text: Color(0xFF15122B),
    textMuted: Color(0xFF66637F),
    accent: AppColors.blue,
  );

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceHigh,
    Color? outline,
    Color? text,
    Color? textMuted,
    Color? accent,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      outline: outline ?? this.outline,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      accent: accent ?? this.accent,
    );
  }

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
    );
  }
}

extension PaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}

/// Seuils de mise en page : en dessous de [compact], navigation en bas ;
/// au-dessus de [expanded], le direct passe en deux colonnes.
class Breakpoints {
  static const compact = 600.0;
  static const expanded = 900.0;
}

ThemeData buildTheme(Brightness brightness) {
  final p = brightness == Brightness.dark ? AppPalette.dark : AppPalette.light;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.blue,
        brightness: brightness,
      ).copyWith(
        primary: p.accent,
        onPrimary: Colors.white,
        secondary: AppColors.red,
        onSecondary: Colors.white,
        surface: p.background,
        onSurface: p.text,
        onSurfaceVariant: p.textMuted,
        surfaceContainer: p.surface,
        surfaceContainerHigh: p.surfaceHigh,
        outline: p.outline,
        outlineVariant: p.outline,
      );

  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  return base.copyWith(
    extensions: [p],
    scaffoldBackgroundColor: p.background,
    textTheme: base.textTheme.apply(bodyColor: p.text, displayColor: p.text),
    appBarTheme: AppBarTheme(
      backgroundColor: p.background,
      foregroundColor: p.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 16,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.red.withValues(alpha: 0.15),
      height: 68,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppColors.live
              : p.textMuted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? p.text : p.textMuted,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: p.surface,
      indicatorColor: AppColors.red.withValues(alpha: 0.15),
      selectedIconTheme: const IconThemeData(color: AppColors.live),
      unselectedIconTheme: IconThemeData(color: p.textMuted),
      selectedLabelTextStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: p.text,
      ),
      unselectedLabelTextStyle: TextStyle(fontSize: 12, color: p.textMuted),
    ),
    cardTheme: CardThemeData(
      color: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: p.outline),
      ),
    ),
    dividerTheme: DividerThemeData(color: p.outline, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.red,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.text,
        minimumSize: const Size(0, 48),
        side: BorderSide(color: p.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.accent, width: 2),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.live,
      linearTrackColor: Colors.transparent,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.surfaceHigh,
      contentTextStyle: TextStyle(color: p.text),
    ),
  );
}
