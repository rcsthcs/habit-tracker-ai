import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Theme-aware extension on BuildContext for quick access to colors.
/// Replaces hardcoded AppTheme.* static references with dark-mode-aware values.
extension ThemeX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => theme.colorScheme;
  TextTheme get textStyles => theme.textTheme;
  bool get isDark => theme.brightness == Brightness.dark;

  // ─── Semantic colors (auto-switch light/dark) ───
  Color get primaryColor => colors.primary;
  Color get secondaryColor => AppColors.secondary;
  Color get successColor => AppColors.success;
  Color get warningColor => AppColors.warning;
  Color get errorColor => AppColors.error;

  // ─── Text ───
  Color get textPrimary => colors.onSurface;
  Color get textSecondary =>
      isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

  // ─── Surfaces ───
  Color get surfaceColor => colors.surface;
  Color get backgroundColor => theme.scaffoldBackgroundColor;

  // ─── Glass ───
  Color get glassColor => isDark ? AppColors.glassDark : AppColors.glassLight;
  Color get glassBorder =>
      isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight;
  Color get dividerColor =>
      isDark ? AppColors.darkDivider : AppColors.lightDivider;
}
