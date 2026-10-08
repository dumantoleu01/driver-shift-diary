import 'package:dartz/dartz.dart';
import 'package:shift_diary/core/error/failures.dart';
import 'package:shift_diary/features/drivers/domain/entities/driver_profile.dart';
import 'package:shift_diary/features/drivers/domain/repositories/drivers_repository.dart';
import 'package:shift_diary/features/drivers/domain/usecases/create_driver.dart';
import 'package:shift_diary/features/drivers/domain/usecases/load_drivers.dart';
import 'package:shift_diary/features/drivers/domain/usecases/rename_driver.dart';
import 'package:shift_diary/features/drivers/domain/usecases/select_driver.dart';
import 'package:shift_diary/features/drivers/presentation/cubit/drivers_cubit.dart';

/// Водители в памяти: идентификаторы `driver-1`, `driver-2`, …
class FakeDriversRepository implements DriversRepository {
  DriverRoster roster = const DriverRoster(
    profiles: [DriverProfile(id: 'driver-1', number: 1)],
    currentId: 'driver-1',
  );

  /// Следующее действие закончится этим сбоем.
  Failure? failure;

  @override
  Future<Either<Failure, DriverRoster>> load() async => _answer(roster);

  @override
  Future<Either<Failure, DriverRoster>> create({String? name}) async {
    final number = roster.nextNumber;
    final added = DriverProfile(
      id: 'driver-$number',
      number: number,
      name: normalizeDriverName(name),
    );
    return _answer(
      DriverRoster(profiles: [...roster.profiles, added], currentId: added.id),
    );
  }

  @override
  Future<Either<Failure, DriverRoster>> rename(String id, String? name) async =>
      _answer(
        DriverRoster(
          profiles: [
            for (final profile in roster.profiles)
              profile.id == id
                  ? profile.renamed(normalizeDriverName(name))
                  : profile,
          ],
          currentId: roster.currentId,
        ),
      );

  @override
  Future<Either<Failure, DriverRoster>> select(String id) async =>
      _answer(DriverRoster(profiles: roster.profiles, currentId: id));

  Either<Failure, DriverRoster> _answer(DriverRoster next) {
    final failed = failure;
    if (failed != null) {
      failure = null;
      return Left(failed);
    }
    roster = next;
    return Right(next);
  }
}

/// Кубит водителей поверх [repo] с уже прочитанным списком.
Future<DriversCubit> loadedDriversCubit(FakeDriversRepository repo) async {
  final cubit = DriversCubit(
    LoadDrivers(repo),
    CreateDriver(repo),
    SelectDriver(repo),
    RenameDriver(repo),
  );
  await cubit.load();
  return cubit;
}
