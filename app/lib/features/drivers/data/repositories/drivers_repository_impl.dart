import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/session/current_driver.dart';
import '../../domain/entities/driver_profile.dart';
import '../../domain/repositories/drivers_repository.dart';
import '../datasources/drivers_local_datasource.dart';

class DriversRepositoryImpl implements DriversRepository {
  DriversRepositoryImpl({
    required this.local,
    required this.session,
    required this.newId,
  });

  final DriversLocalDataSource local;

  /// Кем подписываются запросы. Меняется здесь и только после того, как выбор
  /// сохранён: иначе после перезапуска приложение вернулось бы к прежнему
  /// водителю, а часть поездок осталась бы у нового.
  final CurrentDriver session;

  /// Новый идентификатор водителя.
  final String Function() newId;

  @override
  Future<Either<Failure, DriverRoster>> load() => _guard(() async {
    final saved = await local.read();
    if (saved != null) return saved;

    final first = DriverProfile(id: newId(), number: 1);
    final roster = DriverRoster(profiles: [first], currentId: first.id);
    await local.write(roster);
    return roster;
  });

  @override
  Future<Either<Failure, DriverRoster>> create({String? name}) =>
      _guard(() async {
        final saved = await local.read();
        final profiles = saved?.profiles ?? const <DriverProfile>[];
        final added = DriverProfile(
          id: newId(),
          number: saved?.nextNumber ?? 1,
          name: normalizeDriverName(name),
        );
        final roster = DriverRoster(
          profiles: [...profiles, added],
          currentId: added.id,
        );
        await local.write(roster);
        return roster;
      });

  @override
  Future<Either<Failure, DriverRoster>> select(String id) => _guard(() async {
    final saved = await local.read();
    if (saved == null || saved.profiles.every((profile) => profile.id != id)) {
      throw StateError('Водителя $id нет на этом телефоне');
    }
    final roster = DriverRoster(profiles: saved.profiles, currentId: id);
    await local.write(roster);
    return roster;
  });

  @override
  Future<Either<Failure, DriverRoster>> rename(String id, String? name) =>
      _guard(() async {
        final saved = await local.read();
        if (saved == null ||
            saved.profiles.every((profile) => profile.id != id)) {
          throw StateError('Водителя $id нет на этом телефоне');
        }
        final roster = DriverRoster(
          profiles: [
            for (final profile in saved.profiles)
              profile.id == id
                  ? profile.renamed(normalizeDriverName(name))
                  : profile,
          ],
          // Переименование не меняет выбор: открыт тот же дневник.
          currentId: saved.currentId,
        );
        await local.write(roster);
        return roster;
      });

  Future<Either<Failure, DriverRoster>> _guard(
    Future<DriverRoster> Function() action,
  ) async {
    try {
      final roster = await action();
      session.id = roster.currentId;
      return Right(roster);
    } catch (e) {
      return Left(StorageFailure(e.toString(), cause: e));
    }
  }
}
