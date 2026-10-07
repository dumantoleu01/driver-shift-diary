import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_diary/core/di/injection.dart';
import 'package:shift_diary/core/error/errors.dart';
import 'package:shift_diary/core/router/app_router.dart';
import 'package:shift_diary/core/utils/formatters.dart';
import 'package:shift_diary/features/shifts/domain/entities/payment_method.dart';
import 'package:shift_diary/features/shifts/domain/entities/trip.dart';
import 'package:shift_diary/features/shifts/domain/entities/trip_draft.dart';
import 'package:shift_diary/features/shifts/domain/usecases/add_trip.dart';
import 'package:shift_diary/features/shifts/domain/usecases/get_day_report.dart';
import 'package:shift_diary/features/shifts/domain/usecases/get_diary_index.dart';
import 'package:shift_diary/features/shifts/presentation/cubit/day_cubit.dart';
import 'package:shift_diary/features/shifts/presentation/cubit/trip_form_cubit.dart';
import 'package:shift_diary/features/shifts/presentation/pages/trip_form_page.dart';

import 'helpers/fake_shifts_repository.dart';
import 'helpers/fixtures.dart';
import 'helpers/pump_app.dart';

void main() {
  late FakeShiftsRepository repo;

  setUpAll(loadDateSymbols);

  setUp(() => repo = FakeShiftsRepository());

  TripFormCubit formFor(FakeShiftsRepository repo) => TripFormCubit(
    AddTrip(repo),
    zone: zone,
    day: oct1,
    tripId: 'trip-1',
    now: () => DateTime.utc(2026, 10, 4, 9),
  );

  Future<TripFormCubit> openForm(WidgetTester tester) async {
    usePhoneScreen(tester);
    final cubit = formFor(repo);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: testApp(home: const TripFormView()),
      ),
    );
    return cubit;
  }

  final amountField = find.byKey(const ValueKey('field-amount'));
  final commissionField = find.byKey(const ValueKey('field-commission'));
  final submit = find.byKey(const ValueKey('form-submit'));

  Future<void> tapSubmit(WidgetTester tester) async {
    await tester.tap(submit);
    await tester.pump();
  }

  testWidgets('комиссия подставляется от суммы, «на руки» видно до отправки', (
    tester,
  ) async {
    await openForm(tester);

    await tester.enterText(amountField, '2400');
    await tester.pump();

    expect(tester.widget<TextField>(commissionField).controller!.text, '360');
    expect(
      find.text('Подставлено 15% от суммы — можно изменить'),
      findsOneWidget,
    );
    expect(find.text('На руки: ${formatMoney(2040)}'), findsOneWidget);
  });

  testWidgets('пустая форма: ошибки под полями, запрос не уходит', (
    tester,
  ) async {
    await openForm(tester);

    await tapSubmit(tester);

    expect(find.text('Заполните поле'), findsNWidgets(2));
    expect(repo.sentDrafts, isEmpty);
  });

  testWidgets('дробная сумма: «введите целое число», а не округление', (
    tester,
  ) async {
    await openForm(tester);

    await tester.enterText(amountField, '2400,50');
    await tester.enterText(commissionField, '360');
    await tapSubmit(tester);

    expect(find.text('Введите целое число'), findsOneWidget);
    expect(repo.sentDrafts, isEmpty);
  });

  testWidgets('отказ сервера показывается под тем же полем тем же текстом', (
    tester,
  ) async {
    repo.addResults.add(
      const Left(TripRejectedFailure({'commission': 'must_not_exceed_amount'})),
    );
    await openForm(tester);

    await tester.enterText(amountField, '2400');
    await tapSubmit(tester);
    await tester.pump();

    expect(find.text('Комиссия не может быть больше суммы'), findsOneWidget);
  });

  testWidgets('обрыв связи: поля заблокированы, кнопка предлагает повтор', (
    tester,
  ) async {
    repo.addResults.add(
      Left(NetworkFailure('timeout', cause: ConnectionTimeoutException())),
    );
    await openForm(tester);

    await tester.enterText(amountField, '2400');
    await tapSubmit(tester);
    await tester.pump();

    expect(find.text('Сервер долго не отвечает'), findsOneWidget);
    expect(
      find.text('Если поездка уже дошла до сервера, дубль не появится'),
      findsOneWidget,
    );
    expect(find.text('Повторить отправку'), findsOneWidget);
    expect(tester.widget<TextField>(amountField).enabled, isFalse);
    expect(tester.widget<TextField>(commissionField).enabled, isFalse);
  });

  group('через навигацию', () {
    /// Поездка, которую форма отправит с настройками по умолчанию для
    /// 1 октября: 12:00–12:20 по времени сервиса, наличные.
    final saved = Trip(
      id: 'trip-1',
      start: DateTime.utc(2026, 10, 1, 7),
      end: DateTime.utc(2026, 10, 1, 7, 20),
      amount: 2400,
      payment: PaymentMethod.cash,
      commission: 360,
    );

    /// Главный экран с пустым 1 октября и открытая поверх него форма.
    Future<void> openFromDayPage(WidgetTester tester) async {
      usePhoneScreen(tester);
      repo.index = indexOf([oct1]);

      await getIt.reset();
      getIt.registerFactoryParam<TripFormCubit, TripFormArgs, void>(
        (args, _) => TripFormCubit(
          AddTrip(repo),
          zone: args.zone,
          day: args.day,
          tripId: 'trip-1',
          now: () => DateTime.utc(2026, 10, 4, 9),
        ),
      );
      addTearDown(getIt.reset);

      final dayCubit = DayCubit(GetDiaryIndex(repo), GetDayReport(repo));
      addTearDown(dayCubit.close);
      await tester.pumpWidget(
        BlocProvider.value(
          value: dayCubit,
          child: testApp(router: AppRouter.create()),
        ),
      );
      await dayCubit.start();
      await tester.pumpAndSettle();
      expect(find.text('В этот день поездок нет'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('trip-add')));
      await tester.pumpAndSettle();
      expect(find.text('Новая поездка'), findsOneWidget);
    }

    Future<void> save(WidgetTester tester) async {
      await tester.tap(submit);
      await tester.pumpAndSettle();
    }

    testWidgets('весь путь: главный экран → форма → сохранение → поездка в '
        'списке своего дня', (tester) async {
      await openFromDayPage(tester);

      await tester.enterText(amountField, '2400');
      await tester.pump();
      // С этого момента сервер знает поездку — главный экран её и покажет.
      repo.reports[oct1] = reportOf(oct1, [saved]);
      await save(tester);

      expect(
        repo.sentDrafts.single,
        TripDraft(
          id: 'trip-1',
          start: saved.start,
          end: saved.end,
          amount: 2400,
          payment: PaymentMethod.cash,
          commission: 360,
        ),
      );
      expect(find.text('Новая поездка'), findsNothing);
      expect(find.text('Поездка добавлена'), findsOneWidget);
      expect(find.text('12:00 – 12:20'), findsOneWidget);
    });

    testWidgets(
      'обрыв связи и повтор: запрос тот же, а сообщение — «добавлена», '
      'хотя сервер ответил «уже записана»',
      (tester) async {
        await openFromDayPage(tester);
        repo.addResults.addAll([
          // Первая попытка дошла до сервера, но ответ потерялся.
          Left(NetworkFailure('timeout', cause: ConnectionTimeoutException())),
          // Повтор: сервер узнал поездку по id и новой записи не создал.
          Right(AddedTrip(trip: saved, created: false)),
        ]);

        await tester.enterText(amountField, '2400');
        await tester.pump();
        await save(tester);
        expect(find.text('Повторить отправку'), findsOneWidget);

        repo.reports[oct1] = reportOf(oct1, [saved]);
        await save(tester);

        expect(repo.sentDrafts, hasLength(2));
        expect(repo.sentDrafts[1], repo.sentDrafts[0]);
        expect(find.text('Поездка добавлена'), findsOneWidget);
        expect(find.text('12:00 – 12:20'), findsOneWidget);
      },
    );

    testWidgets(
      'поездка, которая была на сервере ещё до формы: «уже записана»',
      (tester) async {
        await openFromDayPage(tester);
        repo
          ..addResults.add(Right(AddedTrip(trip: saved, created: false)))
          ..reports[oct1] = reportOf(oct1, [saved]);

        await tester.enterText(amountField, '2400');
        await tester.pump();
        await save(tester);

        expect(
          find.text('Такая поездка уже записана — дубль не создан'),
          findsOneWidget,
        );
        expect(find.text('12:00 – 12:20'), findsOneWidget);
      },
    );

    testWidgets('форму закрыли после обрыва: главный экран открывает день '
        'поездки и просит свериться со списком', (tester) async {
      await openFromDayPage(tester);
      repo.addResults.add(
        Left(NetworkFailure('timeout', cause: ConnectionTimeoutException())),
      );

      await tester.enterText(amountField, '2400');
      await tester.pump();
      await save(tester);

      // На самом деле первая попытка дошла.
      repo.reports[oct1] = reportOf(oct1, [saved]);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('Новая поездка'), findsNothing);
      expect(
        find.textContaining('Неизвестно, записалась ли поездка'),
        findsOneWidget,
      );
      expect(find.text('12:00 – 12:20'), findsOneWidget);
    });

    testWidgets('пока идёт отправка, «Назад» форму не закрывает — иначе ответ '
        'пришёл бы в никуда', (tester) async {
      await openFromDayPage(tester);
      repo.holdAdds = true;

      await tester.enterText(amountField, '2400');
      await tester.pump();
      await tester.tap(submit);
      await tester.pump();

      await tester.tap(find.byType(BackButton));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Новая поездка'), findsOneWidget);

      // Ответ пришёл — форма закрывается сама, поездка на экране.
      repo
        ..reports[oct1] = reportOf(oct1, [saved])
        ..replyAdd(Right(AddedTrip(trip: saved, created: true)));
      await tester.pumpAndSettle();

      expect(find.text('Новая поездка'), findsNothing);
      expect(find.text('Поездка добавлена'), findsOneWidget);
      expect(find.text('12:00 – 12:20'), findsOneWidget);
    });

    testWidgets(
      'форму закрыли, ничего не отправив: без сообщений и без запросов',
      (tester) async {
        await openFromDayPage(tester);
        final requestsBefore = repo.requestedDays.length;

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        expect(find.text('Новая поездка'), findsNothing);
        expect(find.textContaining('Неизвестно'), findsNothing);
        expect(repo.requestedDays, hasLength(requestsBefore));
      },
    );

    testWidgets('календарь формы открывается', (tester) async {
      await openFromDayPage(tester);

      await tester.tap(find.byKey(const ValueKey('start-day')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });
  });
}
