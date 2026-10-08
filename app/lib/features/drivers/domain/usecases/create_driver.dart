import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/driver_profile.dart';
import '../repositories/drivers_repository.dart';

/// Параметр — имя нового водителя; `null` — без имени.
class CreateDriver implements UseCase<DriverRoster, String?> {
  CreateDriver(this.repository);

  final DriversRepository repository;

  @override
  Future<Either<Failure, DriverRoster>> call(String? name) =>
      repository.create(name: name);
}
