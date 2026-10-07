import 'package:intl/intl.dart';

import '../config/app_config.dart';
import '../time/calendar_day.dart';

const _locale = 'ru';

/// Сумма с разрядами и знаком валюты: `2 400 ₸`.
///
/// Между разрядами и перед знаком — неразрывные пробелы: сумма не должна
/// переноситься по частям на узком экране.
String formatMoney(int amount) =>
    '${formatNumber(amount)} ${AppConfig.currencySign}';

/// Число с разрядами: `17 000`.
String formatNumber(int value) => NumberFormat('#,##0', _locale).format(value);

/// Время на часах сервиса: `08:10`.
///
/// Принимает только результат `ServiceZone.wallClock` — значение, чьи поля уже
/// равны местному времени.
String formatClock(DateTime wallClock) =>
    '${wallClock.hour.toString().padLeft(2, '0')}:'
    '${wallClock.minute.toString().padLeft(2, '0')}';

/// День для заголовка: `Суббота, 4 октября`.
String formatDayTitle(CalendarDay day) {
  final text = DateFormat(
    'EEEE, d MMMM',
    _locale,
  ).format(DateTime.utc(day.year, day.month, day.day));
  return text[0].toUpperCase() + text.substring(1);
}

/// День для поля формы: `04.10.2026`.
String formatDayShort(CalendarDay day) => DateFormat(
  'dd.MM.yyyy',
  _locale,
).format(DateTime.utc(day.year, day.month, day.day));
