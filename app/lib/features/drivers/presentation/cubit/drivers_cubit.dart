import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/errors.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/driver_profile.dart';
import '../../domain/usecases/create_driver.dart';
import '../../domain/usecases/load_drivers.dart';
import '../../domain/usecases/select_driver.dart';
import 'drivers_state.dart';

/// Водители на этом телефоне и выбор текущего.
///
/// Живёт всё время работы приложения. Экран дня следит за сменой текущего
/// водителя и перечитывает дневник: у другого водителя — другие поездки.
class DriversCubit extends Cubit<DriversState> {
  DriversCubit(this._load, this._create, this._select)
    : super(const DriversState());

  final LoadDrivers _load;
  final CreateDriver _create;
  final SelectDriver _select;

  /// Прочитать список. Вызывается до первого запроса к серверу: без текущего
  /// водителя запрос ушёл бы в общий дневник.
  Future<void> load() async => _apply(await _load(const NoParams()));

  Future<void> create() async => _apply(await _create(const NoParams()));

  Future<void> select(String id) async {
    if (id == state.current?.id) return;
    _apply(await _select(id));
  }

  void _apply(Either<Failure, DriverRoster> result) {
    if (isClosed) return;
    result.fold(
      (failure) => emit(
        DriversState(
          roster: state.roster,
          errorCode: classifyError(failure),
          errorSeq: state.errorSeq + 1,
        ),
      ),
      (roster) => emit(DriversState(roster: roster, errorSeq: state.errorSeq)),
    );
  }
}
