import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:shift_diary/core/network/api_client.dart';

/// Подмена сети: вместо сервера отвечает функция из теста.
///
/// Проверяется весь путь запроса через настоящие Dio и [ApiClient] — без
/// сокетов и без запущенного сервера.
class FakeHttp implements HttpClientAdapter {
  FakeHttp(this._respond);

  final Future<ResponseBody> Function(RequestOptions request) _respond;

  /// Запросы, которые ушли «в сеть», по порядку.
  final List<RequestOptions> requests = [];

  ApiClient get client {
    final dio = Dio(ApiClient.options('http://server.test'))
      ..httpClientAdapter = this;
    return ApiClient(dio);
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return _respond(options);
  }

  @override
  void close({bool force = false}) {}
}

/// Ответ сервера с телом JSON.
Future<ResponseBody> jsonReply(int status, Object? body) async =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
