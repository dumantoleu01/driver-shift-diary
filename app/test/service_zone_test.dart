import 'package:flutter_test/flutter_test.dart';
import 'package:shift_diary/core/time/calendar_day.dart';
import 'package:shift_diary/core/time/service_zone.dart';

import 'helpers/fixtures.dart';

void main() {
  group('ServiceZone', () {
    test('разбирает смещение из ответа сервера', () {
      expect(ServiceZone.parse('+05:00').offset, const Duration(hours: 5));
      expect(
        ServiceZone.parse('-03:30').offset,
        -const Duration(hours: 3, minutes: 30),
      );
      expect(ServiceZone.parse('+00:00').offset, Duration.zero);
    });

    test('не принимает смещение в другом виде', () {
      for (final text in ['', '5', '+5', '+0500', 'Z', 'Asia/Almaty']) {
        expect(
          () => ServiceZone.parse(text),
          throwsFormatException,
          reason: text,
        );
      }
    });

    test('поездка сразу после полуночи относится к новому дню, '
        'хотя по UTC ещё вчера', () {
      // 00:35 1 октября у водителя — это 19:35 30 сентября по UTC.
      final instant = DateTime.utc(2026, 9, 30, 19, 35);

      expect(zone.dayOf(instant), const CalendarDay(2026, 10, 1));
    });

    test('время на часах сервиса не зависит от того, местное значение '
        'пришло или UTC', () {
      final utc = DateTime.utc(2026, 10, 1, 3, 10);
      final local = utc.toLocal();

      for (final instant in [utc, local]) {
        final clock = zone.wallClock(instant);
        expect((clock.hour, clock.minute), (8, 10));
      }
    });

    test('время из формы превращается в момент по поясу сервиса', () {
      final instant = zone.instantAt(
        const CalendarDay(2026, 10, 1),
        hour: 8,
        minute: 10,
      );

      expect(instant, DateTime.utc(2026, 10, 1, 3, 10));
      expect(instant.isUtc, isTrue);
    });

    test('ввод сразу после полуночи даёт момент во вчерашних сутках UTC', () {
      final instant = zone.instantAt(
        const CalendarDay(2026, 10, 1),
        hour: 0,
        minute: 35,
      );

      expect(instant, DateTime.utc(2026, 9, 30, 19, 35));
      expect(zone.dayOf(instant), const CalendarDay(2026, 10, 1));
    });

    test('с другим поясом тот же момент — другой день', () {
      final instant = DateTime.utc(2026, 10, 1, 18, 30); // 23:30 при +05:00

      expect(zone.dayOf(instant), const CalendarDay(2026, 10, 1));
      expect(
        const ServiceZone(Duration(hours: 6)).dayOf(instant),
        const CalendarDay(2026, 10, 2),
      );
    });
  });
}
