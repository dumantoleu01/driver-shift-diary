import 'package:flutter_test/flutter_test.dart';
import 'package:shift_diary/features/shifts/domain/rules/trip_rules.dart';

void main() {
  final start = DateTime.utc(2026, 10, 1, 3, 10);
  final end = DateTime.utc(2026, 10, 1, 3, 32);

  Map<TripField, String> check({
    DateTime? from,
    DateTime? to,
    String amount = '2400',
    String commission = '360',
  }) => checkTripForm(
    start: from ?? start,
    end: to ?? end,
    amountText: amount,
    commissionText: commission,
  );

  group('parseWholeNumber', () {
    test('понимает целые числа, в том числе с пробелами между разрядами', () {
      expect(parseWholeNumber('2400'), 2400);
      expect(parseWholeNumber(' 2 400 '), 2400);
      expect(parseWholeNumber('2 400'), 2400);
      expect(parseWholeNumber('0'), 0);
    });

    test('дробные суммы и мусор числом не считает', () {
      for (final text in [
        '',
        '2400,50',
        '2400.5',
        '-5',
        '1e3',
        'abc',
        '24 00р',
      ]) {
        expect(parseWholeNumber(text), isNull, reason: text);
      }
    });
  });

  group('checkTripForm', () {
    test('годная поездка проходит', () {
      expect(check(), isEmpty);
    });

    test('сумма должна быть больше нуля', () {
      expect(check(amount: '0', commission: '0'), {
        TripField.amount: FieldCodes.mustBePositive,
      });
    });

    test('пустые сумма и комиссия — «заполните поле»', () {
      expect(check(amount: '', commission: ' '), {
        TripField.amount: FieldCodes.required,
        TripField.commission: FieldCodes.required,
      });
    });

    test('дробная сумма — ошибка, а не округление', () {
      expect(
        check(amount: '2400,50')[TripField.amount],
        FieldCodes.invalidType,
      );
    });

    test('слишком большая сумма', () {
      expect(check(amount: '$maxTripAmount'), isEmpty);
      expect(
        check(amount: '${maxTripAmount + 1}')[TripField.amount],
        FieldCodes.tooLarge,
      );
    });

    test('окончание должно быть позже начала; равенство — тоже отказ', () {
      expect(check(to: start), {TripField.end: FieldCodes.mustBeAfterStart});
      expect(check(to: start.subtract(const Duration(minutes: 1))), {
        TripField.end: FieldCodes.mustBeAfterStart,
      });
      expect(check(to: start.add(const Duration(minutes: 1))), isEmpty);
    });

    test('поездка не дольше суток: опечатку в дате потом нечем исправить', () {
      expect(check(to: start.add(const Duration(hours: 24))), isEmpty);
      expect(check(to: start.add(const Duration(hours: 24, minutes: 1))), {
        TripField.end: FieldCodes.tooLong,
      });
      expect(check(to: start.add(const Duration(days: 2, minutes: 20))), {
        TripField.end: FieldCodes.tooLong,
      });
    });

    test('комиссия не больше суммы; ноль и вся сумма допустимы', () {
      expect(check(commission: '2401'), {
        TripField.commission: FieldCodes.mustNotExceedAmount,
      });
      expect(check(commission: '0'), isEmpty);
      expect(check(commission: '2400'), isEmpty);
    });

    test('с негодной суммой комиссия с ней не сравнивается', () {
      expect(check(amount: '0', commission: '100'), {
        TripField.amount: FieldCodes.mustBePositive,
      });
    });

    test('все нарушения возвращаются сразу', () {
      expect(check(to: start, amount: '', commission: 'x'), {
        TripField.end: FieldCodes.mustBeAfterStart,
        TripField.amount: FieldCodes.required,
        TripField.commission: FieldCodes.invalidType,
      });
    });
  });

  group('suggestCommission', () {
    test('15% от суммы, как в образце данных', () {
      expect(suggestCommission(2400, 15), 360);
      expect(suggestCommission(1500, 15), 225);
    });

    test('округляет до целого, а не отбрасывает дробь', () {
      expect(suggestCommission(1990, 15), 299); // 298,5
      expect(suggestCommission(1010, 15), 152); // 151,5
      expect(suggestCommission(1, 15), 0); // 0,15
    });
  });
}
