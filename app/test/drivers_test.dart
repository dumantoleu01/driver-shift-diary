import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shift_diary/core/error/errors.dart';
import 'package:shift_diary/core/session/current_driver.dart';
import 'package:shift_diary/features/drivers/data/datasources/drivers_local_datasource.dart';
import 'package:shift_diary/features/drivers/data/repositories/drivers_repository_impl.dart';
import 'package:shift_diary/features/drivers/domain/entities/driver_profile.dart';

import 'helpers/fake_drivers_repository.dart';

/// Хранилище, в которое нельзя записать.
class _ReadOnlyStore implements DriversLocalDataSource {
  _ReadOnlyStore(this.saved);

  final DriverRoster? saved;

  @override
  Future<DriverRoster?> read() async => saved;

  @override
  Future<void> write(DriverRoster roster) async =>
      throw StorageException('диск переполнен');
}

void main() {
  late CurrentDriver session;
  var issued = 0;

  /// Репозиторий поверх хранилища телефона; идентификаторы — `id-1`, `id-2`, …
  Future<DriversRepositoryImpl> repository() async => DriversRepositoryImpl(
    local: DriversLocalDataSourceImpl(await SharedPreferences.getInstance()),
    session: session,
    newId: () => 'id-${++issued}',
  );

  DriverRoster rosterOf(Either<Failure, DriverRoster> result) =>
      result.getOrElse(() => fail('ожидался список водителей'));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    session = CurrentDriver();
    issued = 0;
  });

  group('водители на телефоне', () {
    test(
      'первый запуск заводит первого водителя и подписывает им запросы',
      () async {
        final roster = rosterOf(await (await repository()).load());

        expect(roster.profiles, [const DriverProfile(id: 'id-1', number: 1)]);
        expect(roster.currentId, 'id-1');
        expect(session.id, 'id-1');
      },
    );

    test('после перезапуска водитель тот же — дневник не теряется', () async {
      await (await repository()).load();
      session = CurrentDriver();

      final roster = rosterOf(await (await repository()).load());

      expect(roster.currentId, 'id-1');
      expect(session.id, 'id-1');
      expect(issued, 1);
    });

    test('новый водитель получает свой идентификатор и сразу выбран', () async {
      final repo = await repository();
      await repo.load();

      final roster = rosterOf(await repo.create());

      expect(roster.profiles, [
        const DriverProfile(id: 'id-1', number: 1),
        const DriverProfile(id: 'id-2', number: 2),
      ]);
      expect(roster.currentId, 'id-2');
      expect(session.id, 'id-2');
    });

    test('выбор другого водителя запоминается до следующего запуска', () async {
      final repo = await repository();
      await repo.load();
      await repo.create();

      await repo.select('id-1');
      session = CurrentDriver();
      final roster = rosterOf(await (await repository()).load());

      expect(roster.currentId, 'id-1');
      expect(roster.profiles, hasLength(2));
      expect(session.id, 'id-1');
    });

    test('выбрать водителя, которого на телефоне нет, нельзя', () async {
      final repo = await repository();
      await repo.load();

      final result = await repo.select('чужой');

      expect(result.isLeft(), isTrue);
      expect(session.id, 'id-1');
    });

    test('повреждённая запись равносильна первому запуску', () async {
      SharedPreferences.setMockInitialValues({
        'drivers.roster.v1': '{"current": "нет такого", "profiles": []}',
      });

      final roster = rosterOf(await (await repository()).load());

      expect(roster.profiles, [const DriverProfile(id: 'id-1', number: 1)]);
      expect(session.id, 'id-1');
    });

    test(
      'если выбор не сохранился, запросы остаются за прежним водителем',
      () async {
        // Иначе после перезапуска приложение вернулось бы к прежнему водителю, а
        // часть поездок осталась бы в дневнике нового.
        session.id = 'id-1';
        final repo = DriversRepositoryImpl(
          local: _ReadOnlyStore(
            const DriverRoster(
              profiles: [
                DriverProfile(id: 'id-1', number: 1),
                DriverProfile(id: 'id-2', number: 2),
              ],
              currentId: 'id-1',
            ),
          ),
          session: session,
          newId: () => 'id-3',
        );

        final selected = await repo.select('id-2');
        final created = await repo.create();

        for (final result in [selected, created]) {
          expect(result.fold(classifyError, (_) => null), ErrorCodes.storage);
        }
        expect(session.id, 'id-1');
      },
    );
  });

  group('DriversCubit', () {
    test('читает список, заводит и выбирает водителей', () async {
      final repo = FakeDriversRepository();
      final cubit = await loadedDriversCubit(repo);
      addTearDown(cubit.close);
      expect(cubit.state.current?.number, 1);

      await cubit.create();
      expect(cubit.state.current?.number, 2);
      expect(cubit.state.roster?.profiles, hasLength(2));

      await cubit.select('driver-1');
      expect(cubit.state.current?.number, 1);
    });

    test('сбой оставляет прежнего водителя и поднимает сообщение', () async {
      final repo = FakeDriversRepository();
      final cubit = await loadedDriversCubit(repo);
      addTearDown(cubit.close);
      repo.failure = const StorageFailure('нет места');

      await cubit.create();

      expect(cubit.state.current?.id, 'driver-1');
      expect(cubit.state.errorCode, ErrorCodes.storage);
      expect(cubit.state.errorSeq, 1);
    });
  });
}
