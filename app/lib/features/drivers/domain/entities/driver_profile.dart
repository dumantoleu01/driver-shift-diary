import 'package:equatable/equatable.dart';

/// Водитель на этом телефоне.
///
/// Это не учётная запись: пароля нет. Идентификатор нужен, чтобы у каждого
/// водителя был свой дневник на сервере.
class DriverProfile extends Equatable {
  const DriverProfile({required this.id, required this.number});

  /// Идентификатор дневника на сервере. Создаётся на телефоне, один раз.
  final String id;

  /// Порядковый номер на этом телефоне: «Водитель 1», «Водитель 2». Имя
  /// собирается при показе, поэтому в хранилище нет текста на каком-то языке.
  final int number;

  @override
  List<Object?> get props => [id, number];
}

/// Все водители на этом телефоне и тот, кто выбран сейчас.
class DriverRoster extends Equatable {
  const DriverRoster({required this.profiles, required this.currentId});

  /// По возрастанию номера.
  final List<DriverProfile> profiles;
  final String currentId;

  DriverProfile get current =>
      profiles.firstWhere((profile) => profile.id == currentId);

  @override
  List<Object?> get props => [profiles, currentId];
}
