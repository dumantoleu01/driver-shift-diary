import '../../../../core/time/calendar_day.dart';
import '../../../../core/time/service_zone.dart';
import '../../domain/entities/diary_index.dart';
import 'json_reader.dart';

abstract final class DiaryIndexModel {
  static DiaryIndex fromJson(Map<String, dynamic> json) => DiaryIndex(
    zone: ServiceZone.parse(json.read<String>('utc_offset')),
    days: [
      for (final entry in json.readObjects('days'))
        DayEntry(
          day: CalendarDay.parse(entry.read<String>('date')),
          trips: entry.read<int>('trips'),
        ),
    ],
  );
}
