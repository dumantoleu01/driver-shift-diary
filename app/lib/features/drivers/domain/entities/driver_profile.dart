import 'package:equatable/equatable.dart';

/// Наибольшая длина имени водителя: оно должно помещаться в шапке экрана.
const maxDriverNameLength = 30;

/// Имя водителя в том виде, в каком оно хранится: без пробелов по краям и без
/// двойных пробелов внутри. Пустое имя — это «имени нет», а не пустая строка:
/// такой водитель показывается под своим номером.
String? normalizeDriverName(String? raw) {
  if (raw == null) return null;
  final compact = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (compact.isEmpty) return null;
  return compact.length <= maxDriverNameLength
      ? compact
      : compact.substring(0, maxDriverNameLength).trimRight();
}

/// Водитель на этом телефоне.
///
/// Это не учётная запись: пароля нет. Идентификатор нужен, чтобы у каждого
/// водителя был свой дневник на сервере.
class DriverProfile extends Equatable {
  const DriverProfile({required this.id, required this.number, this.name});

  /// Идентификатор дневника на сервере. Создаётся на телефоне, один раз, и не
  /// меняется при переименовании — дневник остаётся тем же.
  final String id;

  /// Порядковый номер на этом телефоне. Пока водителю не дали имя, он
  /// показывается как «Водитель 1», «Водитель 2».
  final int number;

  /// Имя, которое водителю дали на этом телефоне. На сервер не уходит: там
  /// водителя знают только по [id].
  final String? name;

  DriverProfile renamed(String? name) =>
      DriverProfile(id: id, number: number, name: name);

  @override
  List<Object?> get props => [id, number, name];
}

/// Все водители на этом телефоне и тот, кто выбран сейчас.
class DriverRoster extends Equatable {
  const DriverRoster({required this.profiles, required this.currentId});

  /// По возрастанию номера.
  final List<DriverProfile> profiles;
  final String currentId;

  DriverProfile get current =>
      profiles.firstWhere((profile) => profile.id == currentId);

  /// Номер, который получит следующий заведённый водитель.
  int get nextNumber =>
      profiles.fold(
        0,
        (max, profile) => profile.number > max ? profile.number : max,
      ) +
      1;

  @override
  List<Object?> get props => [profiles, currentId];
}
