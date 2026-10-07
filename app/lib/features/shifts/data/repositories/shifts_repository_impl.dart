import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/time/calendar_day.dart';
import '../../domain/entities/day_report.dart';
import '../../domain/entities/diary_index.dart';
import '../../domain/entities/trip_draft.dart';
import '../../domain/repositories/shifts_repository.dart';
import '../datasources/shifts_remote_datasource.dart';

class ShiftsRepositoryImpl implements ShiftsRepository {
  ShiftsRepositoryImpl({required this.remoteDataSource});

  final ShiftsRemoteDataSource remoteDataSource;

  @override
  Future<Either<Failure, DiaryIndex>> getIndex() =>
      _guard(remoteDataSource.getIndex);

  @override
  Future<Either<Failure, DayReport>> getDayReport(CalendarDay day) =>
      _guard(() => remoteDataSource.getDayReport(day));

  @override
  Future<Either<Failure, AddedTrip>> addTrip(TripDraft draft) =>
      _guard(() => remoteDataSource.addTrip(draft));

  /// Исключение слоя данных → `Failure`. Исходное исключение сохраняется в
  /// `cause`: по нему экран отличает «нет сети» от «сервер недоступен».
  Future<Either<Failure, T>> _guard<T>(Future<T> Function() request) async {
    try {
      return Right(await request());
    } on TripRejectedException catch (e) {
      return Left(TripRejectedFailure(e.fields, cause: e));
    } on TripIdConflictException catch (e) {
      return Left(TripIdConflictFailure(cause: e));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message, cause: e));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, cause: e));
    } on UnexpectedResponseException catch (e) {
      return Left(ServerFailure(e.message, cause: e));
    } catch (e) {
      return Left(ServerFailure(e.toString(), cause: e));
    }
  }
}
