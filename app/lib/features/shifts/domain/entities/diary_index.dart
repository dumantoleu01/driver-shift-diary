import 'package:equatable/equatable.dart';

import '../../../../core/time/calendar_day.dart';
import '../../../../core/time/service_zone.dart';

/// День, в котором есть поездки.
class DayEntry extends Equatable {
  const DayEntry({required this.day, required this.trips});

  final CalendarDay day;
  final int trips;

  @override
  List<Object?> get props => [day, trips];
}

/// Оглавление дневника: пояс сервиса и дни с поездками.
class DiaryIndex extends Equatable {
  const DiaryIndex({required this.zone, required this.days});

  final ServiceZone zone;

  /// По возрастанию даты.
  final List<DayEntry> days;

  /// Последний день с поездками — с него открывается приложение. «Сегодня»
  /// для этого не годится: если сегодня поездок ещё не было, водитель увидел бы
  /// пустой экран вместо своей последней смены.
  CalendarDay? get latestDay => days.isEmpty ? null : days.last.day;

  @override
  List<Object?> get props => [zone, days];
}
