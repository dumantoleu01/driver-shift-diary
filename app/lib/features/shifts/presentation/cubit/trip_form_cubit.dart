import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/error/errors.dart';
import '../../../../core/time/calendar_day.dart';
import '../../../../core/time/clock_time.dart';
import '../../../../core/time/service_zone.dart';
import '../../domain/entities/payment_method.dart';
import '../../domain/entities/trip_draft.dart';
import '../../domain/rules/trip_rules.dart';
import '../../domain/usecases/add_trip.dart';
import 'trip_form_state.dart';

/// Форма новой поездки.
///
/// Главное здесь — что происходит при обрыве связи. Запрос мог дойти до
/// сервера, а ответ — потеряться, и приложение этого не различит. Поэтому `id`
/// поездки назначается один раз, при открытии формы, а после сбоя связи форма
/// разрешает только повтор той же самой отправки. Сервер узнаёт её по `id` и
/// вторую запись не создаёт.
class TripFormCubit extends Cubit<TripFormState> {
  TripFormCubit(
    this._addTrip, {
    required ServiceZone zone,
    required CalendarDay day,
    required String tripId,
    DateTime Function() now = DateTime.now,
  }) : _zone = zone,
       super(_initial(zone: zone, day: day, tripId: tripId, now: now()));

  final AddTrip _addTrip;
  final ServiceZone _zone;

  /// Сколько длится поездка, которую форма предлагает по умолчанию.
  static const _defaultLength = Duration(minutes: 20);

  /// Начальные значения. Для сегодняшнего дня — «только что закончилась»:
  /// водитель записывает поездку сразу после неё. Для другого дня точного
  /// времени взять неоткуда, предлагается полдень.
  static TripFormState _initial({
    required ServiceZone zone,
    required CalendarDay day,
    required String tripId,
    required DateTime now,
  }) {
    final DateTime end;
    if (zone.dayOf(now) == day) {
      final clock = zone.wallClock(now);
      end = zone.instantAt(day, hour: clock.hour, minute: clock.minute);
    } else {
      end = zone.instantAt(day, hour: 12, minute: 0).add(_defaultLength);
    }
    final start = end.subtract(_defaultLength);
    final startClock = zone.wallClock(start);
    final endClock = zone.wallClock(end);

    return TripFormState(
      tripId: tripId,
      startDay: zone.dayOf(start),
      startTime: ClockTime(startClock.hour, startClock.minute),
      endDay: zone.dayOf(end),
      endTime: ClockTime(endClock.hour, endClock.minute),
    );
  }

  void startDayChanged(CalendarDay day) {
    if (!state.canEdit) return;
    // Обычная поездка заканчивается в день начала: пока водитель не развёл
    // даты сам, дата окончания идёт следом.
    final endFollows = state.endDay == state.startDay;
    _edit(
      state.copyWith(startDay: day, endDay: endFollows ? day : null),
      touched: {TripField.start, TripField.end},
    );
  }

  void startTimeChanged(ClockTime time) {
    if (!state.canEdit) return;
    _edit(
      state.copyWith(startTime: time),
      touched: {TripField.start, TripField.end},
    );
  }

  void endDayChanged(CalendarDay day) {
    if (!state.canEdit) return;
    _edit(state.copyWith(endDay: day), touched: {TripField.end});
  }

  void endTimeChanged(ClockTime time) {
    if (!state.canEdit) return;
    _edit(state.copyWith(endTime: time), touched: {TripField.end});
  }

  void amountChanged(String text) {
    if (!state.canEdit) return;
    var next = state.copyWith(amountText: text);
    if (!state.commissionEdited) {
      final amount = parseWholeNumber(text);
      next = next.copyWith(
        commissionText: amount == null || amount <= 0
            ? ''
            : suggestCommission(
                amount,
                AppConfig.defaultCommissionPercent,
              ).toString(),
      );
    }
    _edit(next, touched: {TripField.amount, TripField.commission});
  }

  void commissionChanged(String text) {
    if (!state.canEdit) return;
    _edit(
      state.copyWith(commissionText: text, commissionEdited: true),
      touched: {TripField.commission},
    );
  }

  void paymentChanged(PaymentMethod payment) {
    if (!state.canEdit) return;
    _edit(state.copyWith(payment: payment), touched: {TripField.payment});
  }

  /// Отправить поездку. Повторный вызов после сбоя шлёт то же самое с тем же
  /// `id`.
  Future<void> submit() async {
    // Двойное нажатие: вторая отправка не начинается, пока идёт первая.
    if (state.isSubmitting || state.status == TripFormStatus.saved) return;

    final start = _zone.instantAt(
      state.startDay,
      hour: state.startTime.hour,
      minute: state.startTime.minute,
    );
    final end = _zone.instantAt(
      state.endDay,
      hour: state.endTime.hour,
      minute: state.endTime.minute,
    );

    final errors = checkTripForm(
      start: start,
      end: end,
      amountText: state.amountText,
      commissionText: state.commissionText,
    );
    if (errors.isNotEmpty) {
      emit(state.copyWith(fieldErrors: errors, clearError: true));
      return;
    }

    emit(
      state.copyWith(
        status: TripFormStatus.submitting,
        fieldErrors: const {},
        clearError: true,
      ),
    );

    final result = await _addTrip(
      TripDraft(
        id: state.tripId,
        start: start,
        end: end,
        amount: parseWholeNumber(state.amountText)!,
        payment: state.payment,
        commission: parseWholeNumber(state.commissionText)!,
      ),
    );
    if (isClosed) return;

    result.fold(_onFailure, (added) {
      emit(state.copyWith(status: TripFormStatus.saved, result: added));
    });
  }

  void _onFailure(Failure failure) {
    if (failure is TripRejectedFailure) {
      // Сервер поездку не записал и объяснил почему. Это определённый ответ:
      // если раньше исход был неизвестен, теперь он известен, и поля снова
      // можно исправлять.
      final known = <TripField, String>{};
      for (final entry in failure.fields.entries) {
        final field = TripField.fromWire(entry.key);
        if (field != null) known[field] = entry.value;
      }
      emit(
        state.copyWith(
          status: TripFormStatus.editing,
          fieldErrors: known,
          // Отказ по полю, которого в форме нет (`id`), под полем не показать.
          errorCode: known.isEmpty ? ErrorCodes.tripRejected : null,
          clearError: known.isNotEmpty,
          outcomeUnknown: false,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: TripFormStatus.editing,
        errorCode: classifyError(failure),
        // Занятый `id` — тоже определённый ответ. Всё остальное (нет сети,
        // тайм-аут, сбой сервера, нечитаемый ответ) оставляет вопрос открытым:
        // поездка могла быть записана.
        outcomeUnknown:
            state.outcomeUnknown || failure is! TripIdConflictFailure,
      ),
    );
  }

  /// Применить правку и снять ошибки с полей, которых она касается: старая
  /// ошибка под только что исправленным полем сбивает с толку.
  void _edit(TripFormState next, {required Set<TripField> touched}) {
    final errors = Map.of(next.fieldErrors)
      ..removeWhere((field, _) => touched.contains(field));
    emit(next.copyWith(fieldErrors: errors, clearError: true));
  }
}
