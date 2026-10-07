import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  const Failure(this.message, {this.cause});

  /// Техническое описание сбоя — для журнала. Водителю не показывается: текст
  /// для него собирает `describeError` по коду.
  final String message;

  /// Исходное исключение. Без него на экране не отличить «нет сети» от «сервер
  /// вернул 500». В [props] намеренно не входит: равенство состояний должно
  /// оставаться по смыслу ошибки, а не по объекту исключения.
  final Object? cause;

  @override
  List<Object?> get props => [message];
}

class ServerFailure extends Failure {
  const ServerFailure(super.message, {super.cause});
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message, {super.cause});
}

/// Сервер не принял поездку. [fields] — код причины по каждому полю; экран
/// показывает их под полями формы, а не общим сообщением.
class TripRejectedFailure extends Failure {
  const TripRejectedFailure(this.fields, {super.cause})
    : super('Trip rejected by server');

  final Map<String, String> fields;

  @override
  List<Object?> get props => [message, fields];
}

/// Под этим `id` уже записана другая поездка.
class TripIdConflictFailure extends Failure {
  const TripIdConflictFailure({super.cause}) : super('Trip id conflict');
}
