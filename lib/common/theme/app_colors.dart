import 'package:flutter/material.dart';

@immutable
class AppPalette {
  const AppPalette._();

  static const lightBackground = Color(0xFFF7F8FA);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightSurfaceMuted = Color(0xFFEEF1F4);
  static const lightPrimary = Color(0xFF4F46E5);
  static const lightPrimaryHover = Color(0xFF4338CA);
  static const lightTextPrimary = Color(0xFF111827);
  static const lightTextSecondary = Color(0xFF6B7280);
  static const lightBorder = Color(0xFFE5E7EB);

  static const darkBackground = Color(0xFF0B1220);
  static const darkCard = Color(0xFF111827);
  static const darkSurfaceMuted = Color(0xFF1F2937);
  static const darkPrimary = Color(0xFF818CF8);
  static const darkPrimaryHover = Color(0xFFA5B4FC);
  static const darkTextPrimary = Color(0xFFF9FAFB);
  static const darkTextSecondary = Color(0xFF9CA3AF);
  static const darkBorder = Color(0xFF374151);

  static const successLight = Color(0xFF15803D);
  static const dangerLight = Color(0xFFB91C1C);
  static const warningLight = Color(0xFFA16207);

  static const successDark = Color(0xFF22C55E);
  static const dangerDark = Color(0xFFEF4444);
  static const warningDark = Color(0xFFF59E0B);
}

@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.danger,
    required this.warning,
    required this.border,
    required this.surfaceMuted,
    required this.chartGrid,
  });

  final Color success;
  final Color danger;
  final Color warning;
  final Color border;
  final Color surfaceMuted;
  final Color chartGrid;

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? danger,
    Color? warning,
    Color? border,
    Color? surfaceMuted,
    Color? chartGrid,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      danger: danger ?? this.danger,
      warning: warning ?? this.warning,
      border: border ?? this.border,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      chartGrid: chartGrid ?? this.chartGrid,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) {
      return this;
    }

    return AppSemanticColors(
      success: Color.lerp(success, other.success, t) ?? success,
      danger: Color.lerp(danger, other.danger, t) ?? danger,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      border: Color.lerp(border, other.border, t) ?? border,
      surfaceMuted:
          Color.lerp(surfaceMuted, other.surfaceMuted, t) ?? surfaceMuted,
      chartGrid: Color.lerp(chartGrid, other.chartGrid, t) ?? chartGrid,
    );
  }
}
