import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shift_diary/core/error/errors.dart';
import 'package:shift_diary/core/time/calendar_day.dart';
import 'package:shift_diary/features/shifts/domain/entities/payment_method.dart';
import 'package:shift_diary/features/shifts/domain/entities/trip.dart';
import 'package:shift_diary/features/shifts/domain/usecases/get_day_report.dart';
import 'package:shift_diary/features/shifts/domain/usecases/get_diary_index.dart';
import 'package:shift_diary/features/shifts/presentation/cubit/day_cubit.dart';
import 'package:shift_diary/features/shifts/presentation/cubit/day_state.dart';

import 'helpers/fake_shifts_repository.dart';
import 'helpers/fixtures.dart';

void main() {
  late FakeShiftsRepository repo;
  late DayCubit cubit;

  /// «Сейчас» по умолчанию: 7 октября, 14:00 по времени сервиса.
  var now = DateTime.utc(2026, 10, 7, 9);

  setUp(() {
    now = DateTime.utc(2026, 10, 7, 9);
    repo = FakeShiftsRepository()..index = indexOf([sep29, oct1, oct4]);
    cubit = DayCubit(GetDiaryIndex(repo), GetDayReport(repo), now: () => now);
  });

  tearDown(() => cubit.close());

  group('DayCubit — открытие', () {
    test(
      'открывается на последнем дне с поездками, а не на «сегодня»',
      () async {
        repo.reports[oct4] = reportOf(oct4, [t1]);

        await cubit.start();

        expect(cubit.state.status, DayStatus.loaded);
        expect(cubit.state.day, oct4);
        expect(cubit.state.report, reportOf(oct4, [t1]));
        expect(cubit.state.zone, zone);
        expect(repo.requestedDays, [oct4]);
      },
    );

    test(
      'в пустом дневнике открывается сегодняшний день по поясу сервиса',
      () async {
        // 20:30 UTC 6 октября — у водителя уже 01:30 7 октября.
        now = DateTime.utc(2026, 10, 6, 20, 30);
        repo.index = indexOf(const []);

        await cubit.start();

        expect(cubit.state.day, const CalendarDay(2026, 10, 7));
        expect(cubit.state.report?.trips, isEmpty);
      },
    );

    test(
      'сбой загрузки — код ошибки в состоянии; повтор восстанавливает',
      () async {
        repo.indexFailure = NetworkFailure(
          'timeout',
          cause: ConnectionTimeoutException(),
        );

        await cubit.start();

        expect(cubit.state.status, DayStatus.error);
        expect(cubit.state.errorCode, ErrorCodes.timeout);

        repo.indexFailure = null;
        await cubit.start();

        expect(cubit.state.status, DayStatus.loaded);
        expect(cubit.state.errorCode, isNull);
        expect(cubit.state.day, oct4);
      },
    );

    test('сбой загрузки дня не теряет выбранный день', () async {
      repo.reportFailure = const ServerFailure('boom');

      await cubit.start();

      expect(cubit.state.status, DayStatus.error);
      expect(cubit.state.errorCode, ErrorCodes.serverUnavailable);
      expect(cubit.state.day, oct4);
    });
  });

  group('DayCubit — переключение дней', () {
    setUp(() => cubit.start());

    test('соседние дни и пустой день', () async {
      await cubit.previousDay();
      expect(cubit.state.day, const CalendarDay(2026, 10, 3));

      await cubit.nextDay();
      await cubit.nextDay();
      expect(cubit.state.day, const CalendarDay(2026, 10, 5));
      // В этом дне поездок нет — это пустой отчёт, а не ошибка.
      expect(cubit.state.status, DayStatus.loaded);
      expect(cubit.state.report?.summary.trips, 0);
    });

    test('выбор дня из календаря', () async {
      repo.reports[oct1] = reportOf(oct1, [t1, t2]);

      await cubit.selectDay(oct1);

      expect(cubit.state.day, oct1);
      expect(cubit.state.report?.trips, [t1, t2]);
    });

    test(
      'пока день грузится, прежний отчёт под новым заголовком не висит',
      () async {
        await pumpEventQueue();
        repo.holdReports = true;

        unawaited(cubit.selectDay(oct1));
        await pumpEventQueue();

        expect(cubit.state.day, oct1);
        expect(cubit.state.status, DayStatus.loading);
        expect(cubit.state.report, isNull);
      },
    );

    test(
      'ответ на старый запрос, пришедший позже нового, отбрасывается',
      () async {
        await pumpEventQueue();
        repo.holdReports = true;

        // Быстро пролистали: 1 октября, затем 2 октября.
        unawaited(cubit.selectDay(oct1));
        await pumpEventQueue();
        unawaited(cubit.selectDay(oct2));
        await pumpEventQueue();

        // Сеть ответила не по порядку: сначала на второй запрос, потом на первый.
        repo.replyReport(oct2, reportOf(oct2));
        await pumpEventQueue();
        repo.replyReport(oct1, reportOf(oct1, [t1, t2]));
        await pumpEventQueue();

        expect(cubit.state.day, oct2);
        expect(cubit.state.report?.day, oct2);
        expect(cubit.state.report?.trips, isEmpty);
      },
    );
  });

  group('DayCubit — обновление', () {
    test('обновление подхватывает новые поездки', () async {
      await cubit.start();
      repo.reports[oct4] = reportOf(oct4, [t1]);

      await cubit.refresh();

      expect(cubit.state.report?.trips, [t1]);
    });

    test(
      'неудачное обновление оставляет данные на экране и сообщает о сбое',
      () async {
        repo.reports[oct4] = reportOf(oct4, [t1]);
        await cubit.start();
        repo.reportFailure = NetworkFailure(
          'offline',
          cause: NetworkException('x'),
        );

        await cubit.refresh();

        expect(cubit.state.status, DayStatus.loaded);
        expect(cubit.state.report?.trips, [t1]);
        expect(cubit.state.noticeCode, ErrorCodes.noInternet);
        expect(cubit.state.noticeSeq, 1);
      },
    );

    test('два сбоя подряд — два сообщения', () async {
      await cubit.start();
      repo.indexFailure = const NetworkFailure('offline');

      await cubit.refresh();
      await cubit.refresh();

      expect(cubit.state.noticeSeq, 2);
    });
  });

  group('DayCubit — после добавления поездки', () {
    test('показывает день поездки по поясу сервиса', () async {
      await cubit.start();
      // Началась в 19:35 UTC 30 сентября — у водителя это 00:35 1 октября.
      final trip = Trip(
        id: 't14',
        start: DateTime.utc(2026, 9, 30, 19, 35),
        end: DateTime.utc(2026, 9, 30, 19, 58),
        amount: 2800,
        payment: PaymentMethod.card,
        commission: 420,
      );
      repo.reports[oct1] = reportOf(oct1, [trip]);

      await cubit.showTrip(trip);

      expect(cubit.state.day, oct1);
      expect(cubit.state.report?.trips, [trip]);
    });

    test('день можно перечитать, даже если он уже на экране', () async {
      await cubit.start();
      repo.reports[oct4] = reportOf(oct4, [t1]);

      await cubit.showDay(oct4);

      expect(cubit.state.day, oct4);
      expect(cubit.state.report?.trips, [t1]);
    });

    test(
      'оглавление запрашивается заново — в нём изменилось число поездок',
      () async {
        await cubit.start();
        final before = repo.indexRequests;

        await cubit.showTrip(t1);

        expect(repo.indexRequests, before + 1);
      },
    );
  });
}
