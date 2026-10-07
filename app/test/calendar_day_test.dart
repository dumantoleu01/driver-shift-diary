import 'package:flutter_test/flutter_test.dart';
import 'package:shift_diary/core/time/calendar_day.dart';

void main() {
  group('CalendarDay', () {
    test('разбирает и записывает дату вида ГГГГ-ММ-ДД', () {
      final day = CalendarDay.parse('2026-10-01');

      expect(day, const CalendarDay(2026, 10, 1));
      expect(day.toIso(), '2026-10-01');
    });

    test('не принимает то, что датой не является', () {
      for (final text in [
        '2026-02-30',
        '2026-13-01',
        '2026-10-1',
        '20261001',
        '01.10.2026',
        '2026-10-01T08:10:00+05:00',
        '',
      ]) {
        expect(
          () => CalendarDay.parse(text),
          throwsFormatException,
          reason: text,
        );
      }
    });

    test('соседние дни переходят через границы месяца и года', () {
      expect(
        const CalendarDay(2026, 9, 30).next,
        const CalendarDay(2026, 10, 1),
      );
      expect(
        const CalendarDay(2026, 10, 1).previous,
        const CalendarDay(2026, 9, 30),
      );
      expect(
        const CalendarDay(2026, 12, 31).next,
        const CalendarDay(2027, 1, 1),
      );
      expect(
        const CalendarDay(2028, 2, 28).next,
        const CalendarDay(2028, 2, 29),
      );
    });

    test('сравнивается по календарю', () {
      const earlier = CalendarDay(2026, 9, 30);
      const later = CalendarDay(2026, 10, 1);

      expect(earlier.isBefore(later), isTrue);
      expect(later.isAfter(earlier), isTrue);
      expect(earlier.compareTo(const CalendarDay(2026, 9, 30)), 0);
    });
  });
}
