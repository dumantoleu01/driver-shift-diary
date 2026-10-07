import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_diary/core/error/errors.dart';
import 'package:shift_diary/core/network/api_client.dart';
import 'package:shift_diary/features/shifts/data/datasources/shifts_remote_datasource.dart';
import 'package:shift_diary/features/shifts/data/repositories/shifts_repository_impl.dart';
import 'package:shift_diary/features/shifts/domain/entities/payment_method.dart';
import 'package:shift_diary/features/shifts/domain/entities/trip_draft.dart';

import 'helpers/fake_http.dart';
import 'helpers/fixtures.dart';
import 'trip_model_test.dart' show t1Json;

final draft = TripDraft(
  id: 't1',
  start: t1.start,
  end: t1.end,
  amount: 2400,
  payment: PaymentMethod.card,
  commission: 360,
);

ShiftsRepositoryImpl repositoryOver(FakeHttp http) => ShiftsRepositoryImpl(
  remoteDataSource: ShiftsRemoteDataSourceImpl(http.client),
);

Future<ResponseBody> errorReply(
  int status,
  String code, {
  Map<String, String>? fields,
}) => jsonReply(status, {
  'error': {'code': code, 'message': 'текст для журнала', 'fields': ?fields},
});

/// Код ошибки, который увидел бы экран.
String codeOf(Either<Failure, Object?> result) =>
    result.fold(classifyError, (_) => fail('ожидалась ошибка'));

void main() {
  group('запросы', () {
    test('оглавление: GET /api/days', () async {
      final http = FakeHttp(
        (_) => jsonReply(200, {
          'utc_offset': '+05:00',
          'days': [
            {'date': '2026-10-01', 'trips': 6},
          ],
        }),
      );

      final result = await repositoryOver(http).getIndex();

      expect(http.requests.single.uri.path, '/api/days');
      expect(result.getOrElse(() => fail('ошибка')).latestDay, oct1);
    });

    test('день: GET /api/days/ГГГГ-ММ-ДД', () async {
      final http = FakeHttp(
        (_) => jsonReply(200, {
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
        }),
      );

      final result = await repositoryOver(http).getDayReport(oct1);

      expect(http.requests.single.uri.path, '/api/days/2026-10-01');
      expect(result, Right<Failure, Object?>(reportOf(oct1, [t1])));
    });
  });

  group('водитель', () {
    Future<ResponseBody> emptyIndex(RequestOptions _) =>
        jsonReply(200, {'utc_offset': '+05:00', 'days': <Object>[]});

    test('каждый запрос подписан текущим водителем', () async {
      final http = FakeHttp((_) => jsonReply(201, t1Json()));
      final repository = ShiftsRepositoryImpl(
        remoteDataSource: ShiftsRemoteDataSourceImpl(
          http.clientAs(() => 'driver-7'),
        ),
      );

      await repository.addTrip(draft);

      expect(http.requests.single.headers['X-Driver-Id'], 'driver-7');
    });

    test(
      'водителя можно сменить на ходу — следующий запрос уйдёт от нового',
      () async {
        var driver = 'driver-1';
        final http = FakeHttp(emptyIndex);
        final repository = ShiftsRepositoryImpl(
          remoteDataSource: ShiftsRemoteDataSourceImpl(
            http.clientAs(() => driver),
          ),
        );

        await repository.getIndex();
        driver = 'driver-2';
        await repository.getIndex();

        expect(http.requests.map((request) => request.headers['X-Driver-Id']), [
          'driver-1',
          'driver-2',
        ]);
      },
    );

    test('пока водитель не выбран, заголовка нет вовсе', () async {
      final http = FakeHttp(emptyIndex);

      await repositoryOver(http).getIndex();

      expect(http.requests.single.headers.containsKey('X-Driver-Id'), isFalse);
    });
  });

  group('добавление поездки', () {
    test('201 — поездка создана; в запросе id и время в UTC', () async {
      final http = FakeHttp((_) => jsonReply(201, t1Json()));

      final result = await repositoryOver(http).addTrip(draft);

      final request = http.requests.single;
      expect(request.method, 'POST');
      expect(request.uri.path, '/api/trips');
      expect(request.data, {
        'id': 't1',
        'start': '2026-10-01T03:10:00.000Z',
        'end': '2026-10-01T03:32:00.000Z',
        'amount': 2400,
        'payment': 'card',
        'commission': 360,
      });
      expect(
        result,
        Right<Failure, AddedTrip>(AddedTrip(trip: t1, created: true)),
      );
    });

    test(
      '200 — такая поездка уже записана; для приложения это успех',
      () async {
        final http = FakeHttp((_) => jsonReply(200, t1Json()));

        final result = await repositoryOver(http).addTrip(draft);

        expect(
          result,
          Right<Failure, AddedTrip>(AddedTrip(trip: t1, created: false)),
        );
      },
    );

    test('422 — отказ с кодами по полям', () async {
      final http = FakeHttp(
        (_) => errorReply(
          422,
          'validation_failed',
          fields: {'amount': 'must_be_positive', 'end': 'must_be_after_start'},
        ),
      );

      final result = await repositoryOver(http).addTrip(draft);

      expect(
        result,
        const Left<Failure, AddedTrip>(
          TripRejectedFailure({
            'amount': 'must_be_positive',
            'end': 'must_be_after_start',
          }),
        ),
      );
      expect(codeOf(result), ErrorCodes.tripRejected);
    });

    test('409 — под этим id другая поездка', () async {
      final http = FakeHttp((_) => errorReply(409, 'id_conflict'));

      final result = await repositoryOver(http).addTrip(draft);

      expect(
        result.swap().getOrElse(() => fail('успех')),
        isA<TripIdConflictFailure>(),
      );
      expect(codeOf(result), ErrorCodes.tripIdConflict);
    });
  });

  group('сбои', () {
    test(
      'сервер не ответил вовремя — «долго не отвечает», а не «нет сети»',
      () async {
        final http = FakeHttp(
          (request) => throw DioException.receiveTimeout(
            timeout: const Duration(seconds: 30),
            requestOptions: request,
          ),
        );

        expect(
          codeOf(await repositoryOver(http).getIndex()),
          ErrorCodes.timeout,
        );
      },
    );

    test('соединение не установилось — «нет связи»', () async {
      final http = FakeHttp(
        (request) => throw DioException.connectionError(
          requestOptions: request,
          reason: 'Connection refused',
        ),
      );

      expect(
        codeOf(await repositoryOver(http).getIndex()),
        ErrorCodes.noInternet,
      );
    });

    test(
      'обрыв посреди ответа — тоже «нет связи», а не «ошибка сервера»',
      () async {
        final http = FakeHttp(
          (_) => throw const SocketException('Connection reset by peer'),
        );

        expect(
          codeOf(await repositoryOver(http).addTrip(draft)),
          ErrorCodes.noInternet,
        );
      },
    );

    test('500 — «сервер недоступен»', () async {
      final http = FakeHttp((_) => errorReply(500, 'internal_error'));

      expect(
        codeOf(await repositoryOver(http).getDayReport(oct1)),
        ErrorCodes.serverUnavailable,
      );
    });

    test(
      'ответ не того вида — отдельная ошибка, повтор тут не поможет',
      () async {
        final http = FakeHttp((_) => jsonReply(200, {'days': 'сюрприз'}));

        expect(
          codeOf(await repositoryOver(http).getIndex()),
          ErrorCodes.badResponse,
        );
      },
    );

    test('поездка со временем без смещения в ответе не принимается', () async {
      final http = FakeHttp(
        (_) => jsonReply(201, {...t1Json(), 'start': '2026-10-01T08:10:00'}),
      );

      expect(
        codeOf(await repositoryOver(http).addTrip(draft)),
        ErrorCodes.badResponse,
      );
    });

    test('ответ с ошибкой не в формате сервера не роняет разбор', () async {
      final http = FakeHttp((_) => jsonReply(502, 'Bad Gateway'));

      expect(
        codeOf(await repositoryOver(http).getIndex()),
        ErrorCodes.serverUnavailable,
      );
    });
  });

  test('ошибка Dio неизвестного вида не выдаёт себя за сбой сети', () {
    final mapped = mapDioError(
      DioException(requestOptions: RequestOptions(), error: StateError('баг')),
    );

    expect(mapped, isA<ServerException>());
  });
}
