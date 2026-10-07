import 'package:equatable/equatable.dart';

import '../../../../core/time/calendar_day.dart';
import 'day_summary.dart';
import 'trip.dart';

/// Всё, что экран показывает за один день: сводка и поездки.
///
/// Приходят одним ответом сервера, поэтому итог всегда сходится со списком.
class DayReport extends Equatable {
  const DayReport({
    required this.day,
    required this.summary,
    required this.trips,
  });

  final CalendarDay day;
  final DaySummary summary;

  /// Поездки по времени начала.
  final List<Trip> trips;

  @override
  List<Object?> get props => [day, summary, trips];
}
