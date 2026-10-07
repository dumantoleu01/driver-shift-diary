import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:shift_diary/core/error/failures.dart';
import 'package:shift_diary/core/time/calendar_day.dart';
import 'package:shift_diary/features/shifts/domain/entities/day_report.dart';
import 'package:shift_diary/features/shifts/domain/entities/diary_index.dart';
import 'package:shift_diary/features/shifts/domain/entities/trip.dart';
import 'package:shift_diary/features/shifts/domain/entities/trip_draft.dart';
import 'package:shift_diary/features/shifts/domain/repositories/shifts_repository.dart';

import 'fixtures.dart';

/// Репозиторий, которым управляет тест.
///
/// По умолчанию отвечает сразу и успешно. С [holdReports] или [holdAdds]
/// запросы повисают, пока тест не ответит на них сам, — так проверяются гонки:
/// ответы можно вернуть в любом порядке.
class FakeShiftsRepository implements ShiftsRepository {
  DiaryIndex index = indexOf(const []);
  Failure? indexFailure;

  /// Отчёты по дням; для дня, которого здесь нет, — пустой отчёт.
  final Map<CalendarDay, DayReport> reports = {};
  Failure? reportFailure;

  bool holdReports = false;
  final Map<CalendarDay, Completer<Either<Failure, DayReport>>> _heldReports =
      {};

  /// Ответы на добавление по очереди; когда очередь пуста — «создана».
  final List<Either<Failure, AddedTrip>> addResults = [];
  bool holdAdds = false;
  final List<Completer<Either<Failure, AddedTrip>>> _heldAdds = [];

  int indexRequests = 0;
  final List<CalendarDay> requestedDays = [];
  final List<TripDraft> sentDrafts = [];

  @override
  Future<Either<Failure, DiaryIndex>> getIndex() async {
    indexRequests++;
    final failure = indexFailure;
    return failure != null ? Left(failure) : Right(index);
  }

  @override
  Future<Either<Failure, DayReport>> getDayReport(CalendarDay day) {
    requestedDays.add(day);
    if (holdReports) {
      return (_heldReports[day] = Completer()).future;
    }
    final failure = reportFailure;
    return Future.value(
      failure != null ? Left(failure) : Right(reports[day] ?? reportOf(day)),
    );
  }

  /// Ответить на повисший запрос дня.
  void replyReport(CalendarDay day, [DayReport? report]) =>
      _heldReports.remove(day)!.complete(Right(report ?? reportOf(day)));

  @override
  Future<Either<Failure, AddedTrip>> addTrip(TripDraft draft) {
    sentDrafts.add(draft);
    if (holdAdds) {
      final completer = Completer<Either<Failure, AddedTrip>>();
      _heldAdds.add(completer);
      return completer.future;
    }
    return Future.value(
      addResults.isNotEmpty ? addResults.removeAt(0) : Right(created(draft)),
    );
  }

  /// Ответить на самый ранний повисший запрос добавления.
  void replyAdd(Either<Failure, AddedTrip> result) =>
      _heldAdds.removeAt(0).complete(result);

  /// Сервер записал поездку такой, какой её прислали.
  static AddedTrip created(TripDraft draft, {bool created = true}) => AddedTrip(
    trip: Trip(
      id: draft.id,
      start: draft.start,
      end: draft.end,
      amount: draft.amount,
      payment: draft.payment,
      commission: draft.commission,
    ),
    created: created,
  );
}
