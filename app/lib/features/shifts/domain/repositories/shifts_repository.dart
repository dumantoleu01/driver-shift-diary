import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/time/calendar_day.dart';
import '../entities/day_report.dart';
import '../entities/diary_index.dart';
import '../entities/trip_draft.dart';

abstract class ShiftsRepository {
  /// Пояс сервиса и дни, в которых есть поездки (`GET /api/days`).
  Future<Either<Failure, DiaryIndex>> getIndex();

  /// Сводка и поездки за день (`GET /api/days/{день}`). Пустой день — не
  /// ошибка: придёт сводка из нулей и пустой список.
  Future<Either<Failure, DayReport>> getDayReport(CalendarDay day);

  /// Добавить поездку (`POST /api/trips`).
  ///
  /// Вызов можно повторять с тем же черновиком сколько угодно раз: вторая
  /// запись не появится.
  Future<Either<Failure, AddedTrip>> addTrip(TripDraft draft);
}
