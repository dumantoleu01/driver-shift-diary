import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/driver_profile.dart';
import '../repositories/drivers_repository.dart';

class SelectDriver implements UseCase<DriverRoster, String> {
  SelectDriver(this.repository);

  final DriversRepository repository;

  @override
  Future<Either<Failure, DriverRoster>> call(String id) =>
      repository.select(id);
}
