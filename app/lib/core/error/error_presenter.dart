import '../../l10n/app_localizations.dart';
import 'exceptions.dart';
import 'failures.dart';

/// Коды ошибок, которые лежат в состоянии экранов.
///
/// В состоянии хранится код, а не готовая фраза: кубит не знает языка
/// интерфейса, а экран не знает исключения. Текст исключения до водителя не
/// доходит никогда — он остаётся в журнале.
abstract final class ErrorCodes {
  static const noInternet = 'NET-01';
  static const timeout = 'NET-02';
  static const serverUnavailable = 'SRV-01';
  static const badResponse = 'SRV-02';
  static const tripRejected = 'TRIP-01';
  static const tripIdConflict = 'TRIP-02';
  static const storage = 'DEV-01';
  static const unknown = 'APP-01';
}

/// Сбой → код ошибки. Работает без `BuildContext`, поэтому вызывается прямо в
/// кубитах.
String classifyError(Object? error) => switch (error) {
  // Failure несёт исходное исключение — по нему классификация точнее.
  Failure(:final cause?) => classifyError(cause),
  TripRejectedFailure() || TripRejectedException() => ErrorCodes.tripRejected,
  TripIdConflictFailure() ||
  TripIdConflictException() => ErrorCodes.tripIdConflict,
  StorageFailure() || StorageException() => ErrorCodes.storage,
  NetworkFailure() => ErrorCodes.noInternet,
  ServerFailure() => ErrorCodes.serverUnavailable,
  ConnectionTimeoutException() => ErrorCodes.timeout,
  NetworkException() => ErrorCodes.noInternet,
  UnexpectedResponseException() => ErrorCodes.badResponse,
  ServerException() => ErrorCodes.serverUnavailable,
  _ => ErrorCodes.unknown,
};

/// Что показать водителю: что случилось и что с этим делать.
class UserFacingError {
  const UserFacingError({required this.title, required this.hint});

  final String title;
  final String hint;
}

/// Код ошибки → текст на языке интерфейса.
UserFacingError describeError(AppLocalizations l10n, String? code) =>
    switch (code) {
      ErrorCodes.noInternet => UserFacingError(
        title: l10n.errNoInternetTitle,
        hint: l10n.errNoInternetHint,
      ),
      ErrorCodes.timeout => UserFacingError(
        title: l10n.errTimeoutTitle,
        hint: l10n.errTimeoutHint,
      ),
      ErrorCodes.serverUnavailable => UserFacingError(
        title: l10n.errServerTitle,
        hint: l10n.errServerHint,
      ),
      ErrorCodes.badResponse => UserFacingError(
        title: l10n.errBadResponseTitle,
        hint: l10n.errBadResponseHint,
      ),
      ErrorCodes.tripRejected => UserFacingError(
        title: l10n.errTripRejectedTitle,
        hint: l10n.errTripRejectedHint,
      ),
      ErrorCodes.tripIdConflict => UserFacingError(
        title: l10n.errTripConflictTitle,
        hint: l10n.errTripConflictHint,
      ),
      ErrorCodes.storage => UserFacingError(
        title: l10n.errStorageTitle,
        hint: l10n.errStorageHint,
      ),
      _ => UserFacingError(
        title: l10n.errUnknownTitle,
        hint: l10n.errUnknownHint,
      ),
    };
