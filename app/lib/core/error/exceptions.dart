/// Сервер ответил отказом.
class ServerException implements Exception {
  ServerException(
    this.message, {
    this.statusCode,
    this.code,
    this.fields = const {},
  });

  final String message;
  final int? statusCode;

  /// Код из тела ответа (`error.code`): `validation_failed`, `id_conflict`, …
  final String? code;

  /// Коды по полям (`error.fields`) — приходят вместе с `422`.
  final Map<String, String> fields;

  @override
  String toString() => 'ServerException($statusCode, $code): $message';
}

/// Ответ пришёл, но не в том виде, какого ждёт приложение.
///
/// Отдельно от [ServerException]: сервер считает, что всё в порядке, и повтор
/// запроса ничего не изменит — менять надо приложение или сервер.
class UnexpectedResponseException implements Exception {
  UnexpectedResponseException(this.message);

  final String message;

  @override
  String toString() => 'UnexpectedResponseException: $message';
}

/// До сервера не удалось дойти.
class NetworkException implements Exception {
  NetworkException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Сервер не ответил за отведённое время.
///
/// Отдельный тип, а не текст внутри [NetworkException]: «нет сети» и «связь
/// медленная» требуют от водителя разных действий. А для отправки поездки это
/// ещё и случай, когда неизвестно, дошёл ли запрос, — повторять его можно
/// только с тем же `id`.
class ConnectionTimeoutException extends NetworkException {
  ConnectionTimeoutException([super.message = 'Connection timeout']);
}

/// Не удалось записать данные в хранилище телефона.
class StorageException implements Exception {
  StorageException(this.message);

  final String message;

  @override
  String toString() => 'StorageException: $message';
}

/// Сервер не принял поездку: по каждому негодному полю — код причины.
class TripRejectedException implements Exception {
  TripRejectedException(this.fields);

  final Map<String, String> fields;

  @override
  String toString() => 'TripRejectedException($fields)';
}

/// Под этим `id` на сервере уже записана другая поездка.
class TripIdConflictException implements Exception {
  @override
  String toString() => 'TripIdConflictException';
}
