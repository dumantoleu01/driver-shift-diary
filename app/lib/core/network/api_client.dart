import 'dart:io';

import 'package:dio/dio.dart';

import '../error/exceptions.dart';

/// Ответ сервера: статус и уже разобранное тело.
class ApiResponse {
  const ApiResponse({required this.statusCode, required this.data});

  final int statusCode;
  final Object? data;
}

/// Единственное место, где приложение говорит с сервером по HTTP.
///
/// Наружу выходят только типизированные исключения из `exceptions.dart`:
/// выше этого слоя никто не знает про Dio и не разбирает текст ошибки.
class ApiClient {
  ApiClient(this._dio);

  /// Настройки запросов.
  ///
  /// Ответа приложение ждёт дольше минуты: сервер на бесплатном хостинге
  /// засыпает и на первый запрос после паузы отвечает до минуты. На «нет сети»
  /// это не влияет — там срабатывает короткое время на соединение.
  static BaseOptions options(String baseUrl) => BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 15),
    sendTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 75),
    contentType: Headers.jsonContentType,
    responseType: ResponseType.json,
    headers: {Headers.acceptHeader: Headers.jsonContentType},
  );

  final Dio _dio;

  Future<ApiResponse> get(String path) => _send(() => _dio.get<Object?>(path));

  Future<ApiResponse> post(String path, Map<String, Object?> body) =>
      _send(() => _dio.post<Object?>(path, data: body));

  Future<ApiResponse> _send(
    Future<Response<Object?>> Function() request,
  ) async {
    try {
      final response = await request();
      return ApiResponse(
        statusCode: response.statusCode ?? 0,
        data: response.data,
      );
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }
}

/// Ошибка Dio → исключение приложения.
Exception mapDioError(DioException e) {
  final text = e.message ?? e.error?.toString() ?? e.type.name;
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return ConnectionTimeoutException(text);
    case DioExceptionType.connectionError:
      return NetworkException(text);
    case DioExceptionType.badResponse:
      return _fromResponse(e.response);
    case DioExceptionType.badCertificate:
    case DioExceptionType.cancel:
    case DioExceptionType.unknown:
      // Обрыв посреди запроса (чтение тела, TLS) Dio отдаёт как `unknown` с
      // исключением `dart:io` внутри. Это сбой связи, а не отказ сервера.
      if (e.error is IOException) return NetworkException(text);
      // Тело с заголовком JSON, которое не разбирается как JSON.
      if (e.error is FormatException) return UnexpectedResponseException(text);
      return ServerException(text);
  }
}

/// Отказ сервера в его формате:
/// `{"error": {"code": "…", "message": "…", "fields": {"поле": "код"}}}`.
ServerException _fromResponse(Response<Object?>? response) {
  final status = response?.statusCode;
  final body = response?.data;
  final error = body is Map ? body['error'] : null;
  if (error is! Map) return ServerException('HTTP $status', statusCode: status);

  final fields = error['fields'];
  return ServerException(
    error['message']?.toString() ?? 'HTTP $status',
    statusCode: status,
    code: error['code']?.toString(),
    fields: fields is Map
        ? {
            for (final entry in fields.entries)
              entry.key.toString(): entry.value.toString(),
          }
        : const {},
  );
}
