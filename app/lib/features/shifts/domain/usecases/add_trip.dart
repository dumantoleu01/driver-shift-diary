import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/trip_draft.dart';
import '../repositories/shifts_repository.dart';

class AddTrip implements UseCase<AddedTrip, TripDraft> {
  AddTrip(this.repository);

  final ShiftsRepository repository;

  @override
  Future<Either<Failure, AddedTrip>> call(TripDraft draft) =>
      repository.addTrip(draft);
}
