import 'package:flutter/material.dart';

/// Unified color palette for light & dark themes with glassmorphism support.
class AppColors {
  // ─── Brand gradients ───
  static const primaryGradient = LinearGradient(
    colors: [Color(0xFF6C63FF), Color(0xFF9B59B6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const secondaryGradient = LinearGradient(
    colors: [Color(0xFF03DAC6), Color(0xFF00BFA5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const accentGradient = LinearGradient(
    colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const successGradient = LinearGradient(
    colors: [Color(0xFF4CAF50), Color(0xFF81C784)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Core colors ───
  static const primary = Color(0xFF6C63FF);
  static const primaryLight = Color(0xFF9B8FFF);
  static const primaryDark = Color(0xFF4A42CC);
  static const secondary = Color(0xFF03DAC6);
  static const secondaryLight = Color(0xFF66FFF0);
  static const accent = Color(0xFFFF6B6B);

  // ─── Semantic ───
  static const success = Color(0xFF4CAF50);
  static const warning = Color(0xFFFF9800);
  static const error = Color(0xFFF44336);
  static const info = Color(0xFF2196F3);

  // ─── Light theme ───
  static const lightBg = Color(0xFFF0EEFF);
  static const lightSurface = Colors.white;
  static const lightSurfaceVariant = Color(0xFFF5F3FF);
  static const lightTextPrimary = Color(0xFF1A1A2E);
  static const lightTextSecondary = Color(0xFF6B7280);
  static const lightDivider = Color(0xFFE8E5FF);

  // ─── Dark theme ───
  static const darkBg = Color(0xFF0D0D1A);
  static const darkSurface = Color(0xFF1A1A2E);
  static const darkSurfaceVariant = Color(0xFF252540);
  static const darkTextPrimary = Color(0xFFF0F0F5);
  static const darkTextSecondary = Color(0xFF9CA3AF);
  static const darkDivider = Color(0xFF2D2D4A);

  // ─── Glassmorphism ───
  static const glassBlurSigma = 20.0;

  static Color glassLight = Colors.white.withValues(alpha: 0.65);
  static Color glassDark = Colors.white.withValues(alpha: 0.06);

  static Color glassBorderLight = Colors.white.withValues(alpha: 0.5);
  static Color glassBorderDark = Colors.white.withValues(alpha: 0.1);

  // ─── Category colors ───
  static const categoryColors = {
    'health': Color(0xFFFF6B6B),
    'fitness': Color(0xFF4ECDC4),
    'nutrition': Color(0xFF95E77E),
    'mindfulness': Color(0xFF9B59B6),
    'productivity': Color(0xFFFF9800),
    'learning': Color(0xFF2196F3),
    'social': Color(0xFFFF69B4),
    'sleep': Color(0xFF5C6BC0),
    'finance': Color(0xFFFFD700),
    'other': Color(0xFF78909C),
  };

  // ─── Mood colors ───
  static const moodColors = [
    Color(0xFFFF6B6B), // 1 - terrible
    Color(0xFFFF9800), // 2 - bad
    Color(0xFFFFEB3B), // 3 - okay
    Color(0xFF81C784), // 4 - good
    Color(0xFF4CAF50), // 5 - great
  ];

  static const moodEmojis = ['😢', '😔', '😐', '😊', '🤩'];
}
