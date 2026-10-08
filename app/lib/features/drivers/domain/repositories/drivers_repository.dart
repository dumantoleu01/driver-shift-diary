import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/driver_profile.dart';

abstract class DriversRepository {
  /// Водители на этом телефоне. При первом запуске создаёт первого.
  Future<Either<Failure, DriverRoster>> load();

  /// Завести нового водителя и сразу выбрать его. На сервере у него будет
  /// свой дневник, начинающийся с образца поездок. Без [name] водитель
  /// показывается под номером.
  Future<Either<Failure, DriverRoster>> create({String? name});

  /// Выбрать другого водителя из уже заведённых.
  Future<Either<Failure, DriverRoster>> select(String id);

  /// Дать водителю имя или сменить его; `null` или пустое — вернуть показ по
  /// номеру. Дневник при этом тот же: меняется только подпись на телефоне.
  Future<Either<Failure, DriverRoster>> rename(String id, String? name);
}
