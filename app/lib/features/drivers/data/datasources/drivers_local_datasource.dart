import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/driver_profile.dart';

abstract class DriversLocalDataSource {
  /// Сохранённый список водителей; `null` — его ещё нет.
  Future<DriverRoster?> read();

  /// Бросает [StorageException], если записать не удалось.
  Future<void> write(DriverRoster roster);
}

class DriversLocalDataSourceImpl implements DriversLocalDataSource {
  DriversLocalDataSourceImpl(this._prefs);

  static const _key = 'drivers.roster.v1';

  final SharedPreferences _prefs;

  @override
  Future<DriverRoster?> read() async {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final roster = DriverRoster(
        currentId: json['current'] as String,
        profiles: [
          for (final item in json['profiles'] as List<dynamic>)
            DriverProfile(
              id: (item as Map<String, dynamic>)['id'] as String,
              number: item['number'] as int,
            ),
        ],
      );
      // Выбранного водителя нет в списке — запись повреждена не меньше, чем
      // нечитаемая.
      roster.current;
      return roster;
    } on Object {
      // Повреждённая запись равносильна отсутствующей: приложение заводит
      // водителя заново, а не падает при каждом запуске.
      return null;
    }
  }

  @override
  Future<void> write(DriverRoster roster) async {
    final saved = await _prefs.setString(
      _key,
      jsonEncode({
        'current': roster.currentId,
        'profiles': [
          for (final profile in roster.profiles)
            {'id': profile.id, 'number': profile.number},
        ],
      }),
    );
    if (!saved) throw StorageException('Не удалось сохранить список водителей');
  }
}
