import 'package:equatable/equatable.dart';

import 'calendar_day.dart';

/// Пояс сервиса — в нём приложение показывает время и считает дни.
///
/// Пояс телефона для этого не годится: водитель в поездке в другой город или с
/// неверно выставленными часами видел бы те же поездки в других днях. Пояс
/// приходит с сервера (`utc_offset` в списке дней), поэтому клиент и сервер не
/// могут разойтись в том, что такое «1 октября».
///
/// В коде приложения нет ни одного `toLocal()`: всё местное время получается
/// только отсюда.
class ServiceZone extends Equatable {
  const ServiceZone(this.offset);

  /// Разобрать смещение вида `+05:00`.
  factory ServiceZone.parse(String text) {
    final match = _pattern.firstMatch(text.trim());
    if (match == null) {
      throw FormatException('Ожидается смещение вида +05:00', text);
    }
    final offset = Duration(
      hours: int.parse(match.group(2)!),
      minutes: int.parse(match.group(3)!),
    );
    return ServiceZone(match.group(1) == '-' ? -offset : offset);
  }

  static final _pattern = RegExp(r'^([+-])(\d{2}):(\d{2})$');

  final Duration offset;

  /// «Часы на стене» у водителя: значение, чьи поля (час, минута, день) равны
  /// местному времени сервиса.
  ///
  /// Результат помечен как UTC только затем, чтобы никто не сдвинул его ещё
  /// раз. Это не момент времени — его можно показывать, но нельзя отправлять.
  DateTime wallClock(DateTime instant) => instant.toUtc().add(offset);

  /// К какому дню относится момент.
  CalendarDay dayOf(DateTime instant) {
    final local = wallClock(instant);
    return CalendarDay(local.year, local.month, local.day);
  }

  /// Момент, когда на часах сервиса [hour]:[minute] в день [day].
  DateTime instantAt(
    CalendarDay day, {
    required int hour,
    required int minute,
  }) =>
      DateTime.utc(day.year, day.month, day.day, hour, minute).subtract(offset);

  @override
  List<Object?> get props => [offset];
}
