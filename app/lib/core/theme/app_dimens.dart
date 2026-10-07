import 'package:flutter/material.dart';

/// Отступы по сетке в 4 px.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Радиусы скругления.
abstract final class AppRadius {
  static const double sm = 10;
  static const double lg = 14;
  static const double card = 20;

  /// Полное скругление — метки и пилюли.
  static const double full = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius cardAll = BorderRadius.all(Radius.circular(card));
}
