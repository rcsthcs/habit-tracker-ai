import 'package:flutter/material.dart';

/// Standard animation constants for consistent motion across the app.
class AppAnimations {
  // ─── Durations ───
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 350);
  static const Duration slow = Duration(milliseconds: 600);
  static const Duration pageTransition = Duration(milliseconds: 400);

  // ─── Curves ───
  static const Curve defaultCurve = Curves.easeOutCubic;
  static const Curve enterCurve = Curves.easeOutCubic;
  static const Curve exitCurve = Curves.easeInCubic;
  static const Curve bounceCurve = Curves.elasticOut;
  static const Curve sharpCurve = Curves.easeInOutCubicEmphasized;

  // ─── Stagger delay between items in a list ───
  static const Duration staggerDelay = Duration(milliseconds: 60);

  /// Calculates stagger delay for item at [index] in a list.
  static Duration staggerDelayFor(int index) =>
      Duration(milliseconds: 60 * index);
}
