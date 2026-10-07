import 'package:equatable/equatable.dart';

import '../../../../core/time/calendar_day.dart';
import '../../../../core/time/service_zone.dart';
import '../../domain/entities/day_report.dart';
import '../../domain/entities/diary_index.dart';

enum DayStatus { initial, loading, loaded, error }

class DayState extends Equatable {
  const DayState({
    this.status = DayStatus.initial,
    this.zone,
    this.days = const [],
    this.day,
    this.report,
    this.errorCode,
    this.noticeCode,
    this.noticeSeq = 0,
  });

  final DayStatus status;

  /// Пояс сервиса. `null`, пока не пришло оглавление: до этого приложение не
  /// знает, какой сейчас день у водителя, и выбирать его не из чего.
  final ServiceZone? zone;

  /// Дни, в которых есть поездки, по возрастанию.
  final List<DayEntry> days;

  /// Выбранный день.
  final CalendarDay? day;

  /// Сводка и поездки выбранного дня; `null`, пока день грузится.
  final DayReport? report;

  /// Код ошибки (`ErrorCodes`) — когда показать вместо содержимого нечего.
  final String? errorCode;

  /// Код ошибки для сообщения поверх содержимого: обновление не удалось, но
  /// прежние данные остаются на экране.
  final String? noticeCode;

  /// Номер сообщения. Без него два одинаковых сбоя подряд слились бы в одно
  /// состояние, и второе сообщение водитель не увидел бы.
  final int noticeSeq;

  DayState copyWith({
    DayStatus? status,
    ServiceZone? zone,
    List<DayEntry>? days,
    CalendarDay? day,
    DayReport? report,
    bool clearReport = false,
    String? errorCode,
    bool clearError = false,
    String? noticeCode,
    int? noticeSeq,
  }) => DayState(
    status: status ?? this.status,
    zone: zone ?? this.zone,
    days: days ?? this.days,
    day: day ?? this.day,
    report: clearReport ? null : (report ?? this.report),
    errorCode: clearError ? null : (errorCode ?? this.errorCode),
    noticeCode: noticeCode ?? this.noticeCode,
    noticeSeq: noticeSeq ?? this.noticeSeq,
  );

  @override
  List<Object?> get props => [
    status,
    zone,
    days,
    day,
    report,
    errorCode,
    noticeCode,
    noticeSeq,
  ];
}
