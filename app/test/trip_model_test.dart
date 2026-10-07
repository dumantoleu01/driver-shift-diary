import 'package:flutter_test/flutter_test.dart';
import 'package:shift_diary/core/time/calendar_day.dart';
import 'package:shift_diary/features/shifts/data/models/day_report_model.dart';
import 'package:shift_diary/features/shifts/data/models/diary_index_model.dart';
import 'package:shift_diary/features/shifts/data/models/trip_model.dart';
import 'package:shift_diary/features/shifts/domain/entities/payment_method.dart';
import 'package:shift_diary/features/shifts/domain/entities/trip_draft.dart';

import 'helpers/fixtures.dart';

/// Поездка `t1` в том виде, в каком её отдаёт сервер.
Map<String, dynamic> t1Json() => {
  'id': 't1',
  'start': '2026-10-01T08:10:00+05:00',
  'end': '2026-10-01T08:32:00+05:00',
  'amount': 2400,
  'payment': 'card',
  'commission': 360,
};

void main() {
  group('parseInstant', () {
    test('время со смещением становится моментом в UTC', () {
      final instant = parseInstant('2026-10-01T08:10:00+05:00');

      expect(instant, DateTime.utc(2026, 10, 1, 3, 10));
      expect(instant.isUtc, isTrue);
    });

    test('понимает и букву Z', () {
      expect(
        parseInstant('2026-10-01T03:10:00Z'),
        DateTime.utc(2026, 10, 1, 3, 10),
      );
    });

    test('время без смещения — ошибка ответа, а не время телефона', () {
      // DateTime.parse на такой строке молча вернул бы местное время.
      expect(() => parseInstant('2026-10-01T08:10:00'), throwsFormatException);
      expect(() => parseInstant('2026-10-01'), throwsFormatException);
    });
  });

  group('TripModel', () {
    test('разбирает поездку из задания', () {
      expect(TripModel.fromJson(t1Json()), t1);
    });

    test('сумма с дробной частью — ошибка, а не округление', () {
      expect(
        () => TripModel.fromJson({...t1Json(), 'amount': 2400.5}),
        throwsFormatException,
      );
    });

    test('сумма строкой — ошибка', () {
      expect(
        () => TripModel.fromJson({...t1Json(), 'amount': '2400'}),
        throwsFormatException,
      );
    });

    test('незнакомый способ оплаты и пропавшее поле — ошибка', () {
      expect(
        () => TripModel.fromJson({...t1Json(), 'payment': 'bitcoin'}),
        throwsFormatException,
      );
      expect(
        () => TripModel.fromJson(t1Json()..remove('commission')),
        throwsFormatException,
      );
    });

    test('в запросе время уходит в UTC с буквой Z', () {
      final body = TripModel.draftToJson(
        TripDraft(
          id: 'abc',
          start: DateTime.utc(2026, 10, 1, 3, 10),
          end: DateTime.utc(2026, 10, 1, 3, 32),
          amount: 2400,
          payment: PaymentMethod.card,
          commission: 360,
        ),
      );

      expect(body, {
        'id': 'abc',
        'start': '2026-10-01T03:10:00.000Z',
        'end': '2026-10-01T03:32:00.000Z',
        'amount': 2400,
        'payment': 'card',
        'commission': 360,
      });
    });

    test('местное время в черновике не уходит без смещения', () {
      // У местного DateTime toIso8601String() смещение не пишет вовсе —
      // сервер такое время не принял бы. Модель сама переводит его в UTC.
      final local = DateTime.utc(2026, 10, 1, 3, 10).toLocal();
      final body = TripModel.draftToJson(
        TripDraft(
          id: 'abc',
          start: local,
          end: local.add(const Duration(minutes: 22)),
          amount: 2400,
          payment: PaymentMethod.card,
          commission: 360,
        ),
      );

      expect(body['start'], '2026-10-01T03:10:00.000Z');
      expect(body['end'], '2026-10-01T03:32:00.000Z');
    });
  });

  group('DayReportModel', () {
    Map<String, dynamic> reportJson() => {
      'date': '2026-10-01',
      'summary': {
        'trips': 1,
        'revenue': 2400,
        'commission': 360,
        'net': 2040,
        'by_payment': {
          'cash': {'trips': 0, 'amount': 0},
          'card': {'trips': 1, 'amount': 2400},
        },
      },
      'trips': [t1Json()],
    };

    test('разбирает сводку и поездки', () {
      expect(DayReportModel.fromJson(reportJson()), reportOf(oct1, [t1]));
    });

    test('сводка берётся с сервера как есть, а не пересчитывается', () {
      final json = reportJson();
      (json['summary'] as Map<String, dynamic>)['net'] = 1;

      expect(DayReportModel.fromJson(json).summary.net, 1);
    });

    test('ответ без сводки — ошибка', () {
      expect(
        () => DayReportModel.fromJson(reportJson()..remove('summary')),
        throwsFormatException,
      );
    });
  });

  group('DiaryIndexModel', () {
    test('разбирает пояс сервиса и дни', () {
      final index = DiaryIndexModel.fromJson({
        'utc_offset': '+05:00',
        'days': [
          {'date': '2026-09-30', 'trips': 6},
          {'date': '2026-10-01', 'trips': 6},
        ],
      });

      expect(index.zone, zone);
      expect(index.days.map((entry) => entry.day), [sep30, oct1]);
      expect(index.latestDay, const CalendarDay(2026, 10, 1));
    });

    test('без пояса сервиса ответ не принимается', () {
      expect(
        () => DiaryIndexModel.fromJson({'days': <Object>[]}),
        throwsFormatException,
      );
    });
  });
}
