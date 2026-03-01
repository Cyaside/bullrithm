import 'package:flutter/material.dart';

@immutable
class AppPalette {
  const AppPalette._();

  static const lightBackground = Color(0xFFF2F3F8);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightSurfaceMuted = Color(0xFFF5F6FA);
  static const lightPrimary = Color(0xFF4C37C7);
  static const lightPrimaryHover = Color(0xFF5E4BDC);
  static const lightTextPrimary = Color(0xFF1C2230);
  static const lightTextSecondary = Color(0xFF8A90A1);
  static const lightBorder = Color(0xFFE8EAF1);

  static const darkBackground = Color(0xFF0D0F1B);
  static const darkCard = Color(0xFF161A2A);
  static const darkSurfaceMuted = Color(0xFF1F2438);
  static const darkPrimary = Color(0xFF7561F2);
  static const darkPrimaryHover = Color(0xFF8A7AFF);
  static const darkTextPrimary = Color(0xFFF4F5FA);
  static const darkTextSecondary = Color(0xFFA3A9BB);
  static const darkBorder = Color(0xFF2B324B);

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
