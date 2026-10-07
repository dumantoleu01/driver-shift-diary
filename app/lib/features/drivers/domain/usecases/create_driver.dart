import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/driver_profile.dart';
import '../repositories/drivers_repository.dart';

class CreateDriver implements UseCase<DriverRoster, NoParams> {
  CreateDriver(this.repository);

  final DriversRepository repository;

  @override
  Future<Either<Failure, DriverRoster>> call(NoParams params) =>
      repository.create();
}
