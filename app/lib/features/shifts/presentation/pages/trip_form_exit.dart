import '../../../../core/time/calendar_day.dart';
import '../../domain/entities/trip.dart';

/// С чем закрылась форма поездки. `null` — её просто закрыли, ничего не
/// отправив или получив от сервера определённый отказ.
sealed class TripFormExit {
  const TripFormExit();
}

/// Сервер подтвердил: поездка записана.
class TripSaved extends TripFormExit {
  const TripSaved(this.trip);

  final Trip trip;
}

/// Форму закрыли после сбоя связи: поездка могла записаться, а могла и нет.
///
/// Главный экран открывает [day] — день этой поездки, — чтобы водитель увидел,
/// что на самом деле лежит на сервере, прежде чем вводить её заново.
class TripOutcomeUnknown extends TripFormExit {
  const TripOutcomeUnknown(this.day);

  final CalendarDay day;
}
