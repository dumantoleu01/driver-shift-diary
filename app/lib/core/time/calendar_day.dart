import 'package:equatable/equatable.dart';

/// Календарный день без времени и без пояса: «1 октября 2026».
///
/// Отдельный тип, а не `DateTime`: у `DateTime` всегда есть время и пояс, и день,
/// записанный им, незаметно сдвигается при первом же `toLocal()` или `toUtc()`.
class CalendarDay extends Equatable implements Comparable<CalendarDay> {
  const CalendarDay(this.year, this.month, this.day);

  /// Разобрать `ГГГГ-ММ-ДД` — в таком виде день приходит с сервера.
  factory CalendarDay.parse(String text) {
    final match = _pattern.firstMatch(text);
    if (match == null) {
      throw FormatException('Ожидается дата вида ГГГГ-ММ-ДД', text);
    }
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);

    // `DateTime.utc(2026, 2, 30)` не падает, а молча превращается во 2 марта —
    // по этому превращению и видно, что такой даты нет.
    final normalized = DateTime.utc(year, month, day);
    if (normalized.year != year ||
        normalized.month != month ||
        normalized.day != day) {
      throw FormatException('Такой даты нет в календаре', text);
    }
    return CalendarDay(year, month, day);
  }

  static final _pattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  final int year;
  final int month;
  final int day;

  CalendarDay get next => addDays(1);

  CalendarDay get previous => addDays(-1);

  CalendarDay addDays(int count) {
    // Арифметика в UTC: в нём нет перевода часов, и «плюс день» — всегда
    // следующая дата, а не «плюс 24 часа» с возможным промахом.
    final moved = DateTime.utc(year, month, day + count);
    return CalendarDay(moved.year, moved.month, moved.day);
  }

  bool isBefore(CalendarDay other) => compareTo(other) < 0;

  bool isAfter(CalendarDay other) => compareTo(other) > 0;

  /// `ГГГГ-ММ-ДД` — в таком виде день уходит в адрес запроса.
  String toIso() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  @override
  int compareTo(CalendarDay other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  List<Object?> get props => [year, month, day];

  @override
  String toString() => toIso();
}
