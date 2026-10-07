import 'package:equatable/equatable.dart';

import '../../domain/entities/driver_profile.dart';

class DriversState extends Equatable {
  const DriversState({this.roster, this.errorCode, this.errorSeq = 0});

  /// Водители на этом телефоне; `null`, пока список не прочитан.
  final DriverRoster? roster;

  /// Код ошибки (`ErrorCodes`) последнего неудачного действия.
  final String? errorCode;

  /// Номер ошибки: два одинаковых сбоя подряд — два сообщения.
  final int errorSeq;

  DriverProfile? get current => roster?.current;

  @override
  List<Object?> get props => [roster, errorCode, errorSeq];
}
