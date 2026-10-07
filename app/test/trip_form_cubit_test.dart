import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_diary/core/error/errors.dart';
import 'package:shift_diary/core/time/calendar_day.dart';
import 'package:shift_diary/core/time/clock_time.dart';
import 'package:shift_diary/features/shifts/domain/entities/payment_method.dart';
import 'package:shift_diary/features/shifts/domain/entities/trip_draft.dart';
import 'package:shift_diary/features/shifts/domain/rules/trip_rules.dart';
import 'package:shift_diary/features/shifts/domain/usecases/add_trip.dart';
import 'package:shift_diary/features/shifts/presentation/cubit/trip_form_cubit.dart';
import 'package:shift_diary/features/shifts/presentation/cubit/trip_form_state.dart';

import 'helpers/fake_shifts_repository.dart';
import 'helpers/fixtures.dart';

void main() {
  late FakeShiftsRepository repo;
  late TripFormCubit cubit;

  /// Форма для [day]; «сейчас» — 4 октября, 15:47:30 по времени сервиса.
  TripFormCubit open(CalendarDay day, {DateTime? now}) => TripFormCubit(
    AddTrip(repo),
    zone: zone,
    day: day,
    tripId: 'trip-1',
    now: () => now ?? DateTime.utc(2026, 10, 4, 10, 47, 30),
  );

  /// Заполнить форму годной поездкой: 2400, карта, комиссия подставится сама.
  void fill() {
    cubit
      ..amountChanged('2400')
      ..paymentChanged(PaymentMethod.card);
  }

  final timeout = Left<Failure, AddedTrip>(
    NetworkFailure('timeout', cause: ConnectionTimeoutException()),
  );

  setUp(() {
    repo = FakeShiftsRepository();
    cubit = open(oct4);
  });

  tearDown(() => cubit.close());

  group('TripFormCubit — начальные значения', () {
    test('для сегодняшнего дня — поездка, которая только что закончилась', () {
      expect(cubit.state.endDay, oct4);
      expect(cubit.state.endTime, const ClockTime(15, 47));
      expect(cubit.state.startDay, oct4);
      expect(cubit.state.startTime, const ClockTime(15, 27));
    });

    test('сразу после полуночи начало оказывается во вчерашнем дне', () {
      // 00:10 5 октября по времени сервиса.
      cubit = open(
        const CalendarDay(2026, 10, 5),
        now: DateTime.utc(2026, 10, 4, 19, 10),
      );

      expect(cubit.state.startDay, oct4);
      expect(cubit.state.startTime, const ClockTime(23, 50));
      expect(cubit.state.endDay, const CalendarDay(2026, 10, 5));
      expect(cubit.state.endTime, const ClockTime(0, 10));
    });

    test('для другого дня — полдень этого дня', () {
      cubit = open(oct1);

      expect(cubit.state.startDay, oct1);
      expect(cubit.state.startTime, const ClockTime(12, 0));
      expect(cubit.state.endDay, oct1);
      expect(cubit.state.endTime, const ClockTime(12, 20));
    });
  });

  group('TripFormCubit — ввод', () {
    test('комиссия подставляется как 15% суммы', () {
      cubit.amountChanged('2400');
      expect(cubit.state.commissionText, '360');

      cubit.amountChanged('1990');
      expect(cubit.state.commissionText, '299');

      cubit.amountChanged('');
      expect(cubit.state.commissionText, '');
    });

    test('комиссию, введённую вручную, сумма больше не перезаписывает', () {
      cubit
        ..amountChanged('2400')
        ..commissionChanged('500')
        ..amountChanged('3000');

      expect(cubit.state.commissionText, '500');
    });

    test('перенос начала сдвигает окончание следом — длительность та же', () {
      cubit.startDayChanged(oct1);
      expect(cubit.state.endDay, oct1);
      expect(cubit.state.endTime, const ClockTime(15, 47));

      cubit.startTimeChanged(const ClockTime(9, 0));
      expect(cubit.state.endDay, oct1);
      expect(cubit.state.endTime, const ClockTime(9, 20));
    });

    test('начало перед самой полуночью уводит окончание на следующий день', () {
      cubit.startTimeChanged(const ClockTime(23, 50));

      expect(cubit.state.startDay, oct4);
      expect(cubit.state.endDay, const CalendarDay(2026, 10, 5));
      expect(cubit.state.endTime, const ClockTime(0, 10));
    });

    test('форма, открытая сразу после полуночи: перенос начала на другой день '
        'не оставляет окончание на прежнем', () {
      // По умолчанию 23:50 4 октября – 00:10 5 октября: даты уже разные.
      cubit = open(
        const CalendarDay(2026, 10, 5),
        now: DateTime.utc(2026, 10, 4, 19, 10),
      );

      cubit.startDayChanged(oct2);

      expect(cubit.state.startDay, oct2);
      expect(cubit.state.endDay, const CalendarDay(2026, 10, 3));
      expect(cubit.state.endTime, const ClockTime(0, 10));
    });

    test(
      'своё окончание водитель задаёт после начала — оно не сбрасывается',
      () {
        cubit
          ..startTimeChanged(const ClockTime(9, 0))
          ..endTimeChanged(const ClockTime(9, 45));

        expect(cubit.state.startTime, const ClockTime(9, 0));
        expect(cubit.state.endTime, const ClockTime(9, 45));
      },
    );
  });

  group('TripFormCubit — проверка перед отправкой', () {
    test('пустая форма не отправляется, ошибки — под полями', () async {
      await cubit.submit();

      expect(cubit.state.fieldErrors, {
        TripField.amount: FieldCodes.required,
        TripField.commission: FieldCodes.required,
      });
      expect(repo.sentDrafts, isEmpty);
    });

    test('окончание раньше начала не отправляется', () async {
      fill();
      cubit.endTimeChanged(const ClockTime(15, 0));

      await cubit.submit();

      expect(cubit.state.fieldErrors, {
        TripField.end: FieldCodes.mustBeAfterStart,
      });
      expect(repo.sentDrafts, isEmpty);
    });

    test('окончание через двое суток не отправляется', () async {
      fill();
      cubit.endDayChanged(const CalendarDay(2026, 10, 6));

      await cubit.submit();

      expect(cubit.state.fieldErrors, {TripField.end: FieldCodes.tooLong});
      expect(repo.sentDrafts, isEmpty);
    });

    test('поездка через полночь проходит', () async {
      fill();
      cubit
        ..startTimeChanged(const ClockTime(23, 48))
        ..endDayChanged(const CalendarDay(2026, 10, 5))
        ..endTimeChanged(const ClockTime(0, 14));

      await cubit.submit();

      expect(cubit.state.status, TripFormStatus.saved);
      expect(repo.sentDrafts.single.start, DateTime.utc(2026, 10, 4, 18, 48));
      expect(repo.sentDrafts.single.end, DateTime.utc(2026, 10, 4, 19, 14));
    });

    test('правка поля снимает ошибку под ним', () async {
      await cubit.submit();

      cubit.amountChanged('2400');

      expect(cubit.state.fieldErrors, isEmpty);
    });
  });

  group('TripFormCubit — отправка', () {
    test('уходит черновик с id формы и моментами по поясу сервиса', () async {
      fill();

      await cubit.submit();

      expect(
        repo.sentDrafts.single,
        TripDraft(
          id: 'trip-1',
          // 15:27 и 15:47 по времени сервиса (+05:00).
          start: DateTime.utc(2026, 10, 4, 10, 27),
          end: DateTime.utc(2026, 10, 4, 10, 47),
          amount: 2400,
          payment: PaymentMethod.card,
          commission: 360,
        ),
      );
      expect(cubit.state.status, TripFormStatus.saved);
      expect(cubit.state.result?.created, isTrue);
    });

    test('«такая поездка уже записана» — тоже успех', () async {
      fill();
      repo.holdAdds = true;

      unawaited(cubit.submit());
      await pumpEventQueue();
      repo.replyAdd(
        Right(
          FakeShiftsRepository.created(repo.sentDrafts.single, created: false),
        ),
      );
      await pumpEventQueue();

      expect(cubit.state.status, TripFormStatus.saved);
      expect(cubit.state.result?.created, isFalse);
    });

    test('двойное нажатие отправляет один запрос', () async {
      fill();
      repo.holdAdds = true;

      unawaited(cubit.submit());
      unawaited(cubit.submit());
      await pumpEventQueue();

      expect(repo.sentDrafts, hasLength(1));
      expect(cubit.state.isSubmitting, isTrue);
    });
  });

  group('TripFormCubit — обрыв связи', () {
    test('повтор уходит с тем же id и тем же содержимым', () async {
      fill();
      repo.addResults.add(timeout);

      await cubit.submit();
      await cubit.submit();

      expect(repo.sentDrafts, hasLength(2));
      expect(repo.sentDrafts[1], repo.sentDrafts[0]);
      expect(repo.sentDrafts[1].id, 'trip-1');
      expect(cubit.state.status, TripFormStatus.saved);
    });

    test('после обрыва поля блокируются: исправленная поездка стала бы '
        'второй, если первая всё-таки дошла', () async {
      fill();
      repo.addResults.add(timeout);

      await cubit.submit();

      expect(cubit.state.errorCode, ErrorCodes.timeout);
      expect(cubit.state.outcomeUnknown, isTrue);
      expect(cubit.state.canEdit, isFalse);

      cubit
        ..amountChanged('9900')
        ..commissionChanged('1')
        ..paymentChanged(PaymentMethod.cash)
        ..startTimeChanged(const ClockTime(1, 0))
        ..endTimeChanged(const ClockTime(2, 0));

      expect(cubit.state.amountText, '2400');
      expect(cubit.state.commissionText, '360');
      expect(cubit.state.payment, PaymentMethod.card);
      expect(cubit.state.startTime, const ClockTime(15, 27));
      expect(cubit.state.endTime, const ClockTime(15, 47));
    });

    test('сколько бы раз связь ни рвалась, id не меняется', () async {
      fill();
      repo.addResults.addAll([
        timeout,
        const Left(NetworkFailure('offline')),
        const Left(ServerFailure('502')),
      ]);

      for (var attempt = 0; attempt < 4; attempt++) {
        await cubit.submit();
      }

      expect(repo.sentDrafts.map((draft) => draft.id).toSet(), {'trip-1'});
      expect(repo.sentDrafts.toSet(), hasLength(1));
      expect(cubit.state.status, TripFormStatus.saved);
    });
  });

  group('TripFormCubit — отказ сервера', () {
    test('коды по полям показываются под полями, форма остаётся открытой для '
        'правки', () async {
      fill();
      repo.addResults.add(
        const Left(
          TripRejectedFailure({
            'amount': 'too_large',
            'end': 'must_be_after_start',
          }),
        ),
      );

      await cubit.submit();

      expect(cubit.state.fieldErrors, {
        TripField.amount: FieldCodes.tooLarge,
        TripField.end: FieldCodes.mustBeAfterStart,
      });
      expect(cubit.state.errorCode, isNull);
      expect(cubit.state.canEdit, isTrue);
    });

    test('отказ по полю, которого нет в форме, — общим сообщением', () async {
      fill();
      repo.addResults.add(
        const Left(TripRejectedFailure({'id': 'invalid_value'})),
      );

      await cubit.submit();

      expect(cubit.state.fieldErrors, isEmpty);
      expect(cubit.state.errorCode, ErrorCodes.tripRejected);
    });

    test('определённый отказ после обрыва снова открывает поля', () async {
      fill();
      repo.addResults.addAll([
        timeout,
        const Left(TripRejectedFailure({'amount': 'too_large'})),
      ]);

      await cubit.submit();
      await cubit.submit();

      expect(cubit.state.outcomeUnknown, isFalse);
      expect(cubit.state.canEdit, isTrue);
    });

    test('занятый id — определённый отказ, поля не блокируются', () async {
      fill();
      repo.addResults.add(const Left(TripIdConflictFailure()));

      await cubit.submit();

      expect(cubit.state.errorCode, ErrorCodes.tripIdConflict);
      expect(cubit.state.outcomeUnknown, isFalse);
    });
  });
}
