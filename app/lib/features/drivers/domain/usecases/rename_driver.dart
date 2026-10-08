import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/driver_profile.dart';
import '../repositories/drivers_repository.dart';

class RenameDriverParams {
  const RenameDriverParams({required this.id, required this.name});

  final String id;

  /// Новое имя; `null` или пустое — убрать имя.
  final String? name;
}

class RenameDriver implements UseCase<DriverRoster, RenameDriverParams> {
  RenameDriver(this.repository);

  final DriversRepository repository;

  @override
  Future<Either<Failure, DriverRoster>> call(RenameDriverParams params) =>
      repository.rename(params.id, params.name);
}
