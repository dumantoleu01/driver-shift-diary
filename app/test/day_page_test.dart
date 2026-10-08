import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_diary/core/error/errors.dart';
import 'package:shift_diary/core/time/calendar_day.dart';
import 'package:shift_diary/core/utils/formatters.dart';
import 'package:shift_diary/features/drivers/presentation/cubit/drivers_cubit.dart';
import 'package:shift_diary/features/shifts/domain/entities/payment_method.dart';
import 'package:shift_diary/features/shifts/domain/entities/trip.dart';
import 'package:shift_diary/features/shifts/domain/usecases/get_day_report.dart';
import 'package:shift_diary/features/shifts/domain/usecases/get_diary_index.dart';
import 'package:shift_diary/features/shifts/presentation/cubit/day_cubit.dart';
import 'package:shift_diary/features/shifts/presentation/pages/day_page.dart';

import 'helpers/fake_drivers_repository.dart';
import 'helpers/fake_shifts_repository.dart';
import 'helpers/fixtures.dart';
import 'helpers/pump_app.dart';

void main() {
  late FakeShiftsRepository repo;
  late DayCubit cubit;
  late FakeDriversRepository driversRepo;
  late DriversCubit drivers;

  setUpAll(loadDateSymbols);

  setUp(() async {
    repo = FakeShiftsRepository()..index = indexOf([sep30, oct1]);
    cubit = DayCubit(GetDiaryIndex(repo), GetDayReport(repo));
    driversRepo = FakeDriversRepository();
    drivers = await loadedDriversCubit(driversRepo);
  });

  tearDown(() async {
    await cubit.close();
    await drivers.close();
  });

  /// Экран дня с обоими кубитами — как в приложении.
  Widget page() => MultiBlocProvider(
    providers: [
      BlocProvider.value(value: drivers),
      BlocProvider.value(value: cubit),
    ],
    child: testApp(home: const DayPage()),
  );

  Future<void> open(WidgetTester tester) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(page());
    await cubit.start();
    await tester.pumpAndSettle();
  }

  String textOf(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(ValueKey(key))).data!;

  testWidgets('сводка и поездки дня из задания', (tester) async {
    repo.reports[oct1] = reportOf(oct1, [t1, t2]);

    await open(tester);

    expect(textOf(tester, 'day-title'), 'Четверг, 1 октября');
    expect(textOf(tester, 'summary-net'), formatMoney(3315));
    expect(textOf(tester, 'summary-trips'), '2');
    expect(textOf(tester, 'summary-revenue'), formatMoney(3900));
    expect(textOf(tester, 'summary-commission'), formatMoney(585));

    final cash = find.byKey(const ValueKey('summary-cash'));
    final card = find.byKey(const ValueKey('summary-card'));
    expect(
      find.descendant(of: cash, matching: find.text(formatMoney(1500))),
      findsOneWidget,
    );
    expect(
      find.descendant(of: cash, matching: find.text('1 поездка')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text(formatMoney(2400))),
      findsOneWidget,
    );

    // Время — по часам сервиса (+05:00), в каком бы поясе ни шёл тест.
    expect(find.text('08:10 – 08:32'), findsOneWidget);
    expect(find.text('09:05 – 09:20'), findsOneWidget);
    expect(find.text('22 мин · комиссия ${formatMoney(360)}'), findsOneWidget);
  });

  testWidgets('суммы пишутся с разрядами и знаком валюты', (tester) async {
    expect(formatMoney(2400), '2 400 ₸');
    expect(formatMoney(17000), '17 000 ₸');
    expect(formatMoney(0), '0 ₸');
  });

  testWidgets('поездка через полночь помечена, чтобы время не читалось как '
      'ошибка', (tester) async {
    final overnight = Trip(
      id: 't13',
      start: DateTime.utc(2026, 9, 30, 18, 48), // 23:48
      end: DateTime.utc(2026, 9, 30, 19, 14), // 00:14 следующего дня
      amount: 3000,
      payment: PaymentMethod.cash,
      commission: 450,
    );
    repo
      ..index = indexOf([sep30])
      ..reports[sep30] = reportOf(sep30, [overnight]);

    await open(tester);

    expect(find.text('23:48 – 00:14'), findsOneWidget);
    expect(find.textContaining('след. день'), findsOneWidget);
  });

  testWidgets('пустой день — сводка из нулей и подсказка, а не ошибка', (
    tester,
  ) async {
    repo.index = indexOf([oct2]);

    await open(tester);

    expect(textOf(tester, 'summary-net'), formatMoney(0));
    expect(find.text('В этот день поездок нет'), findsOneWidget);
  });

  testWidgets('стрелки листают дни', (tester) async {
    repo.reports[oct2] = reportOf(oct2);
    await open(tester);

    await tester.tap(find.byKey(const ValueKey('day-next')));
    await tester.pumpAndSettle();

    expect(textOf(tester, 'day-title'), 'Пятница, 2 октября');
    expect(cubit.state.day, oct2);

    await tester.tap(find.byKey(const ValueKey('day-previous')));
    await tester.tap(find.byKey(const ValueKey('day-previous')));
    await tester.pumpAndSettle();

    expect(cubit.state.day, const CalendarDay(2026, 9, 30));
  });

  for (final day in const [
    CalendarDay(2019, 12, 31),
    CalendarDay(2030, 5, 5),
  ]) {
    testWidgets(
      'календарь открывается и для дня далеко от сегодняшнего: $day',
      (tester) async {
        // Сервер принимает поездки с 2000 по 2099 год — такой день может
        // оказаться последним в дневнике, и приложение откроется на нём.
        repo.index = indexOf([day]);
        await open(tester);

        await tester.tap(find.byKey(const ValueKey('day-pick')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(DatePickerDialog), findsOneWidget);
      },
    );
  }

  testWidgets('долгая загрузка объясняет, почему долго', (tester) async {
    usePhoneScreen(tester);
    repo.holdReports = true;
    await tester.pumpWidget(page());
    unawaited(cubit.start());
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      find.textContaining('Сервер отвечает дольше обычного'),
      findsNothing,
    );

    await tester.pump(const Duration(seconds: 4));

    expect(
      find.textContaining('Сервер отвечает дольше обычного'),
      findsOneWidget,
    );

    repo.replyReport(oct1, reportOf(oct1, [t1]));
    await tester.pumpAndSettle();

    expect(find.text('08:10 – 08:32'), findsOneWidget);
  });

  testWidgets('сбой загрузки — понятный текст и повтор; текст исключения на '
      'экран не попадает', (tester) async {
    repo.indexFailure = NetworkFailure(
      'SocketException: Connection refused (OS Error: errno = 61)',
      cause: NetworkException('SocketException: Connection refused'),
    );

    await open(tester);

    expect(find.text('Нет связи с сервером'), findsOneWidget);
    expect(find.textContaining('SocketException'), findsNothing);
    expect(find.byKey(const ValueKey('trip-add')), findsNothing);

    repo
      ..indexFailure = null
      ..reports[oct1] = reportOf(oct1, [t1]);
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();

    expect(find.text('08:10 – 08:32'), findsOneWidget);
  });

  testWidgets('неудачное обновление оставляет данные и показывает сообщение', (
    tester,
  ) async {
    repo.reports[oct1] = reportOf(oct1, [t1]);
    await open(tester);
    repo.reportFailure = const NetworkFailure('offline');

    await cubit.refresh();
    // Первый кадр доставляет состояние слушателю, второй рисует сообщение.
    await tester.pump();
    await tester.pump();

    expect(find.text('08:10 – 08:32'), findsOneWidget);
    expect(find.textContaining('Нет связи с сервером'), findsOneWidget);
  });

  group('водители', () {
    testWidgets('в шапке видно, чей дневник открыт', (tester) async {
      await open(tester);

      expect(find.text('Водитель 1'), findsOneWidget);
    });

    /// Открыть список водителей.
    Future<void> openDrivers(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('driver-button')));
      await tester.pumpAndSettle();
    }

    final nameField = find.byKey(const ValueKey('driver-name-field'));
    final confirm = find.byKey(const ValueKey('driver-name-confirm'));

    testWidgets('новый водитель с именем: экран перечитывает дневник и '
        'открывает его последний день', (tester) async {
      repo.reports[oct1] = reportOf(oct1, [t1]);
      await open(tester);
      expect(find.text('08:10 – 08:32'), findsOneWidget);

      await openDrivers(tester);
      await tester.tap(find.byKey(const ValueKey('driver-new')));
      await tester.pumpAndSettle();
      // У нового водителя на сервере другой дневник.
      repo
        ..index = indexOf([sep30])
        ..reports[sep30] = reportOf(sep30, [t2]);
      await tester.enterText(nameField, 'Болат');
      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(find.text('Болат'), findsOneWidget);
      expect(drivers.state.current?.name, 'Болат');
      expect(textOf(tester, 'day-title'), 'Среда, 30 сентября');
      expect(find.text('08:10 – 08:32'), findsNothing);
      expect(cubit.state.report?.trips, [t2]);
    });

    testWidgets('новый водитель без имени называется по номеру', (
      tester,
    ) async {
      await open(tester);

      await openDrivers(tester);
      await tester.tap(find.byKey(const ValueKey('driver-new')));
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(find.text('Водитель 2'), findsOneWidget);
      expect(drivers.state.current?.name, isNull);
    });

    testWidgets('отмена в окне имени никого не заводит', (tester) async {
      await open(tester);

      await openDrivers(tester);
      await tester.tap(find.byKey(const ValueKey('driver-new')));
      await tester.pumpAndSettle();
      await tester.enterText(nameField, 'Болат');
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();

      expect(drivers.state.roster?.profiles, hasLength(1));
    });

    testWidgets('переименование: имя меняется в списке и в шапке, а дневник '
        'не перечитывается', (tester) async {
      repo.reports[oct1] = reportOf(oct1, [t1]);
      await open(tester);
      final requestsBefore = repo.indexRequests;

      await openDrivers(tester);
      await tester.tap(find.byKey(const ValueKey('driver-rename-1')));
      await tester.pumpAndSettle();
      await tester.enterText(nameField, 'Али');
      await tester.tap(confirm);
      await tester.pumpAndSettle();

      // Список остаётся открытым: имя видно и в нём, и в шапке под ним.
      expect(find.text('Али'), findsNWidgets(2));
      expect(drivers.state.current?.id, 'driver-1');
      // Тот же водитель, тот же дневник — запрашивать нечего.
      expect(repo.indexRequests, requestsBefore);
      expect(find.text('08:10 – 08:32'), findsOneWidget);
    });

    testWidgets('в окне переименования стоит нынешнее имя', (tester) async {
      await drivers.rename('driver-1', 'Али');
      await open(tester);

      await openDrivers(tester);
      await tester.tap(find.byKey(const ValueKey('driver-rename-1')));
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(nameField).controller!.text, 'Али');
    });

    testWidgets('имя, которое уже есть у другого водителя, не принимается', (
      tester,
    ) async {
      await drivers.rename('driver-1', 'Али');
      await drivers.create('Болат');
      await open(tester);

      await openDrivers(tester);
      await tester.tap(find.byKey(const ValueKey('driver-rename-2')));
      await tester.pumpAndSettle();
      await tester.enterText(nameField, ' али ');
      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(find.text('Такое имя уже есть'), findsOneWidget);
      expect(drivers.state.current?.name, 'Болат');

      // Своё прежнее имя оставить можно.
      await tester.enterText(nameField, 'Болат');
      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(find.text('Такое имя уже есть'), findsNothing);
      expect(find.byKey(const ValueKey('driver-name-field')), findsNothing);
    });

    testWidgets('длинное имя не ломает шапку', (tester) async {
      await drivers.rename('driver-1', 'Александр Константинопольский');
      await open(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Дневник смен'), findsOneWidget);
    });

    testWidgets('переключение между водителями', (tester) async {
      await drivers.create();
      await open(tester);
      expect(find.text('Водитель 2'), findsOneWidget);
      final requestsBefore = repo.indexRequests;

      await tester.tap(find.byKey(const ValueKey('driver-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('driver-1')));
      await tester.pumpAndSettle();

      expect(drivers.state.current?.id, 'driver-1');
      expect(find.text('Водитель 1'), findsOneWidget);
      expect(repo.indexRequests, greaterThan(requestsBefore));
    });

    testWidgets('выбор того же водителя ничего не перечитывает', (
      tester,
    ) async {
      await open(tester);
      final requestsBefore = repo.indexRequests;

      await tester.tap(find.byKey(const ValueKey('driver-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('driver-1')));
      await tester.pumpAndSettle();

      expect(repo.indexRequests, requestsBefore);
    });

    testWidgets(
      'если водителя не удалось сохранить, дневник остаётся прежним',
      (tester) async {
        repo.reports[oct1] = reportOf(oct1, [t1]);
        await open(tester);
        driversRepo.failure = const StorageFailure('нет места');

        await openDrivers(tester);
        await tester.tap(find.byKey(const ValueKey('driver-new')));
        await tester.pumpAndSettle();
        await tester.tap(confirm);
        await tester.pumpAndSettle();

        expect(find.text('Водитель 1'), findsOneWidget);
        expect(find.text('08:10 – 08:32'), findsOneWidget);
        expect(
          find.textContaining('Не удалось сохранить на телефоне'),
          findsOneWidget,
        );
      },
    );
  });
}
