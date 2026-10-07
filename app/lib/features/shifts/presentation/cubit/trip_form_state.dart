import 'package:equatable/equatable.dart';

import '../../../../core/time/calendar_day.dart';
import '../../../../core/time/clock_time.dart';
import '../../domain/entities/payment_method.dart';
import '../../domain/entities/trip_draft.dart';
import '../../domain/rules/trip_rules.dart';

enum TripFormStatus { editing, submitting, saved }

class TripFormState extends Equatable {
  const TripFormState({
    required this.tripId,
    required this.startDay,
    required this.startTime,
    required this.endDay,
    required this.endTime,
    this.amountText = '',
    this.payment = PaymentMethod.cash,
    this.commissionText = '',
    this.commissionEdited = false,
    this.fieldErrors = const {},
    this.status = TripFormStatus.editing,
    this.errorCode,
    this.outcomeUnknown = false,
    this.result,
  });

  /// `id` поездки. Назначен при открытии формы и не меняется, сколько бы раз
  /// ни нажали «Сохранить»: по нему сервер узнаёт повтор.
  final String tripId;

  final CalendarDay startDay;
  final ClockTime startTime;
  final CalendarDay endDay;
  final ClockTime endTime;

  /// Сумма и комиссия — как их ввёл водитель, строкой. В число они
  /// превращаются при проверке: «2400,50» должно стать ошибкой под полем, а не
  /// молча округлиться.
  final String amountText;
  final PaymentMethod payment;
  final String commissionText;

  /// Водитель сам менял комиссию — форма больше не подставляет её от суммы.
  final bool commissionEdited;

  /// Ошибки под полями: поле → код причины (`FieldCodes`).
  final Map<TripField, String> fieldErrors;

  final TripFormStatus status;

  /// Код общей ошибки (`ErrorCodes`) — сбой связи или отказ сервера целиком.
  final String? errorCode;

  /// Отправка закончилась сбоем связи: неизвестно, записана ли поездка.
  ///
  /// С этого момента поля заблокированы и возможен только повтор. Если бы
  /// водитель поправил сумму и отправил снова, на сервере могли бы оказаться
  /// обе поездки — прежняя, которая всё-таки дошла, и исправленная.
  final bool outcomeUnknown;

  /// Что записал сервер; есть только при `status == saved`.
  final AddedTrip? result;

  bool get isSubmitting => status == TripFormStatus.submitting;

  /// Можно ли менять поля.
  bool get canEdit => status == TripFormStatus.editing && !outcomeUnknown;

  TripFormState copyWith({
    CalendarDay? startDay,
    ClockTime? startTime,
    CalendarDay? endDay,
    ClockTime? endTime,
    String? amountText,
    PaymentMethod? payment,
    String? commissionText,
    bool? commissionEdited,
    Map<TripField, String>? fieldErrors,
    TripFormStatus? status,
    String? errorCode,
    bool clearError = false,
    bool? outcomeUnknown,
    AddedTrip? result,
  }) => TripFormState(
    tripId: tripId,
    startDay: startDay ?? this.startDay,
    startTime: startTime ?? this.startTime,
    endDay: endDay ?? this.endDay,
    endTime: endTime ?? this.endTime,
    amountText: amountText ?? this.amountText,
    payment: payment ?? this.payment,
    commissionText: commissionText ?? this.commissionText,
    commissionEdited: commissionEdited ?? this.commissionEdited,
    fieldErrors: fieldErrors ?? this.fieldErrors,
    status: status ?? this.status,
    errorCode: clearError ? null : (errorCode ?? this.errorCode),
    outcomeUnknown: outcomeUnknown ?? this.outcomeUnknown,
    result: result ?? this.result,
  );

  @override
  List<Object?> get props => [
    tripId,
    startDay,
    startTime,
    endDay,
    endTime,
    amountText,
    payment,
    commissionText,
    commissionEdited,
    fieldErrors,
    status,
    errorCode,
    outcomeUnknown,
    result,
  ];
}
