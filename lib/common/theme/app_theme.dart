import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppPalette.lightPrimary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppPalette.lightPrimary,
          secondary: AppPalette.lightPrimaryHover,
          surface: AppPalette.lightCard,
          onSurface: AppPalette.lightTextPrimary,
          error: AppPalette.dangerLight,
        );

    return _baseTheme(
      colorScheme: scheme,
      scaffoldBackgroundColor: AppPalette.lightBackground,
      semanticColors: const AppSemanticColors(
        success: AppPalette.successLight,
        danger: AppPalette.dangerLight,
        warning: AppPalette.warningLight,
        border: AppPalette.lightBorder,
        surfaceMuted: AppPalette.lightSurfaceMuted,
        chartGrid: Color(0xFFECEFF3),
      ),
      dividerColor: AppPalette.lightBorder,
      cardColor: AppPalette.lightCard,
      textPrimary: AppPalette.lightTextPrimary,
      textSecondary: AppPalette.lightTextSecondary,
    );
  }

  static ThemeData dark() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppPalette.darkPrimary,
          brightness: Brightness.dark,
        ).copyWith(
          primary: AppPalette.darkPrimary,
          secondary: AppPalette.darkPrimaryHover,
          surface: AppPalette.darkCard,
          onSurface: AppPalette.darkTextPrimary,
          error: AppPalette.dangerDark,
        );

    return _baseTheme(
      colorScheme: scheme,
      scaffoldBackgroundColor: AppPalette.darkBackground,
      semanticColors: const AppSemanticColors(
        success: AppPalette.successDark,
        danger: AppPalette.dangerDark,
        warning: AppPalette.warningDark,
        border: AppPalette.darkBorder,
        surfaceMuted: AppPalette.darkSurfaceMuted,
        chartGrid: Color(0xFF263246),
      ),
      dividerColor: AppPalette.darkBorder,
      cardColor: AppPalette.darkCard,
      textPrimary: AppPalette.darkTextPrimary,
      textSecondary: AppPalette.darkTextSecondary,
    );
  }

  static ThemeData _baseTheme({
    required ColorScheme colorScheme,
    required Color scaffoldBackgroundColor,
    required AppSemanticColors semanticColors,
    required Color dividerColor,
    required Color cardColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      cardColor: cardColor,
      dividerColor: dividerColor,
      extensions: <ThemeExtension<dynamic>>[semanticColors],
    );

    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme);
    final textTheme = baseTextTheme.copyWith(
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        fontSize: 16,
        color: textPrimary,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        fontSize: 14,
        color: textPrimary,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        fontSize: 12,
        color: textSecondary,
      ),
      labelMedium: baseTextTheme.labelMedium?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: textSecondary,
      ),
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBackgroundColor,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: dividerColor),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: semanticColors.surfaceMuted,
        hintStyle: textTheme.bodyMedium?.copyWith(color: textSecondary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.2),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return colorScheme.primary.withValues(alpha: 0.14);
            }
            return semanticColors.surfaceMuted;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return colorScheme.primary;
            }
            return textSecondary;
          }),
          textStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return textTheme.labelMedium?.copyWith(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            );
          }),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return BorderSide(
                color: colorScheme.primary.withValues(alpha: 0.2),
              );
            }
            return BorderSide(color: semanticColors.border);
          }),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardColor,
        elevation: 0,
        indicatorColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.bodySmall?.copyWith(
            color: selected ? colorScheme.primary : textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? colorScheme.primary : textSecondary,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cardColor,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

extension AppThemeX on BuildContext {
  AppSemanticColors get semanticColors =>
      Theme.of(this).extension<AppSemanticColors>()!;
}
