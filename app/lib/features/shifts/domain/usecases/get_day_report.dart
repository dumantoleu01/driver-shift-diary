import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/time/calendar_day.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/day_report.dart';
import '../repositories/shifts_repository.dart';

class GetDayReport implements UseCase<DayReport, CalendarDay> {
  GetDayReport(this.repository);

  final ShiftsRepository repository;

  @override
  Future<Either<Failure, DayReport>> call(CalendarDay day) =>
      repository.getDayReport(day);
}
