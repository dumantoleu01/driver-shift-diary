import 'package:flutter/material.dart';

/// Цветовые токены приложения.
///
/// Подключаются как [ThemeExtension] и доступны через `context.colors`. В
/// виджетах цвета числами не пишутся: светлая и тёмная темы меняются здесь, в
/// одном месте.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bgPrimary,
    required this.bgCard,
    required this.bgMuted,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.onAccent,
    required this.positive,
    required this.cash,
    required this.cashBg,
    required this.card,
    required this.cardBg,
    required this.negative,
    required this.negativeBg,
  });

  /// Фон экрана.
  final Color bgPrimary;

  /// Фон карточек поверх экрана.
  final Color bgCard;

  /// Приглушённая подложка внутри карточки.
  final Color bgMuted;
  final Color border;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  /// Основной цвет действий.
  final Color accent;
  final Color onAccent;

  /// Деньги, которые водитель получает.
  final Color positive;

  /// Наличные: цвет подписи и подложка метки.
  final Color cash;
  final Color cashBg;

  /// Карта: цвет подписи и подложка метки.
  final Color card;
  final Color cardBg;

  /// Ошибки.
  final Color negative;
  final Color negativeBg;

  static const light = AppColors(
    bgPrimary: Color(0xFFF3F4F7),
    bgCard: Color(0xFFFFFFFF),
    bgMuted: Color(0xFFF3F4F7),
    border: Color(0xFFE2E5EA),
    textPrimary: Color(0xFF14171C),
    textSecondary: Color(0xFF596271),
    textTertiary: Color(0xFF8992A0),
    accent: Color(0xFF2457D6),
    onAccent: Color(0xFFFFFFFF),
    positive: Color(0xFF0F7A56),
    cash: Color(0xFF8A5300),
    cashBg: Color(0xFFFFF1D1),
    card: Color(0xFF2146B8),
    cardBg: Color(0xFFE4EBFF),
    negative: Color(0xFFB3261E),
    negativeBg: Color(0xFFFCE9E7),
  );

  static const dark = AppColors(
    bgPrimary: Color(0xFF0E1013),
    bgCard: Color(0xFF191C21),
    bgMuted: Color(0xFF22262D),
    border: Color(0xFF2C313A),
    textPrimary: Color(0xFFF1F3F6),
    textSecondary: Color(0xFFA9B1BD),
    textTertiary: Color(0xFF7A8391),
    accent: Color(0xFF8AA9FF),
    onAccent: Color(0xFF0B1B45),
    positive: Color(0xFF5ED3A5),
    cash: Color(0xFFFFCB6B),
    cashBg: Color(0xFF3A2D10),
    card: Color(0xFFA6BCFF),
    cardBg: Color(0xFF1B2748),
    negative: Color(0xFFFF8A80),
    negativeBg: Color(0xFF3B1715),
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      bgPrimary: mix(bgPrimary, other.bgPrimary),
      bgCard: mix(bgCard, other.bgCard),
      bgMuted: mix(bgMuted, other.bgMuted),
      border: mix(border, other.border),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      textTertiary: mix(textTertiary, other.textTertiary),
      accent: mix(accent, other.accent),
      onAccent: mix(onAccent, other.onAccent),
      positive: mix(positive, other.positive),
      cash: mix(cash, other.cash),
      cashBg: mix(cashBg, other.cashBg),
      card: mix(card, other.card),
      cardBg: mix(cardBg, other.cardBg),
      negative: mix(negative, other.negative),
      negativeBg: mix(negativeBg, other.negativeBg),
    );
  }
}

extension AppColorsX on BuildContext {
  /// Цвета текущей темы.
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
