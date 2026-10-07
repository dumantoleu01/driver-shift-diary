import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/errors.dart';
import '../../../../core/time/calendar_day.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/diary_index.dart';
import '../../domain/entities/trip.dart';
import '../../domain/usecases/get_day_report.dart';
import '../../domain/usecases/get_diary_index.dart';
import 'day_state.dart';

/// Экран дня: сводка, список поездок и переключение дней.
///
/// Открывается на последнем дне, в котором есть поездки. День выбирается в
/// поясе сервиса, а не телефона — пояс приходит вместе с оглавлением.
class DayCubit extends Cubit<DayState> {
  DayCubit(
    this._getIndex,
    this._getDayReport, {
    DateTime Function() now = DateTime.now,
  }) : _now = now,
       super(const DayState());

  final GetDiaryIndex _getIndex;
  final GetDayReport _getDayReport;
  final DateTime Function() _now;

  /// Растёт с каждым запросом. Ответ на более старый запрос, пришедший позже
  /// нового (сеть не обязана отвечать по порядку), отбрасывается — иначе при
  /// быстром листании под заголовком «4 октября» остались бы поездки 3-го.
  int _requestSeq = 0;

  /// Открыли приложение или нажали «Повторить» на ошибке загрузки.
  Future<void> start() => _load(day: state.day, quiet: false);

  /// Сменился водитель: ни выбранный день, ни поездки прежнего водителя к
  /// новому не относятся. Экран очищается и открывается заново — на последнем
  /// дне с поездками уже нового водителя.
  Future<void> restart() {
    emit(const DayState());
    return _load(day: null, quiet: false);
  }

  /// Потянули экран вниз. Прежние данные остаются на месте; если обновить не
  /// удалось, об этом скажет сообщение поверх них.
  Future<void> refresh() => _load(day: state.day, quiet: true);

  Future<void> selectDay(CalendarDay day) {
    if (day == state.day && state.status == DayStatus.loaded) {
      return Future.value();
    }
    return _load(day: day, quiet: false);
  }

  Future<void> previousDay() async {
    final day = state.day;
    if (day != null) await selectDay(day.previous);
  }

  Future<void> nextDay() async {
    final day = state.day;
    if (day != null) await selectDay(day.next);
  }

  /// Добавили поездку — показать её день. Он может быть не тем, что выбран
  /// сейчас: день считается по времени начала поездки.
  Future<void> showTrip(Trip trip) =>
      showDay(state.zone?.dayOf(trip.start) ?? state.day);

  /// Открыть день заново, даже если он уже на экране: данные на сервере могли
  /// измениться.
  Future<void> showDay(CalendarDay? day) => _load(day: day, quiet: false);

  Future<void> _load({required CalendarDay? day, required bool quiet}) async {
    final seq = ++_requestSeq;
    final keepReport = quiet && state.report != null;
    if (!keepReport) {
      emit(
        state.copyWith(
          status: DayStatus.loading,
          day: day,
          clearReport: true,
          clearError: true,
        ),
      );
    }

    // Оглавление запрашивается каждый раз: в нём пояс сервиса и число поездок
    // по дням, а после добавления поездки оно меняется.
    final index = await _getIndex(const NoParams());
    if (_isStale(seq)) return;
    final diary = index.fold<DiaryIndex?>((failure) {
      _fail(failure, keepReport);
      return null;
    }, (value) => value);
    if (diary == null) return;

    final chosen = day ?? diary.latestDay ?? diary.zone.dayOf(_now());
    emit(state.copyWith(zone: diary.zone, days: diary.days, day: chosen));

    final report = await _getDayReport(chosen);
    if (_isStale(seq)) return;
    report.fold(
      (failure) => _fail(failure, keepReport),
      (report) => emit(
        state.copyWith(
          status: DayStatus.loaded,
          report: report,
          clearError: true,
        ),
      ),
    );
  }

  bool _isStale(int seq) => isClosed || seq != _requestSeq;

  void _fail(Failure failure, bool keepReport) {
    final code = classifyError(failure);
    if (keepReport) {
      emit(state.copyWith(noticeCode: code, noticeSeq: state.noticeSeq + 1));
    } else {
      emit(state.copyWith(status: DayStatus.error, errorCode: code));
    }
  }
}
