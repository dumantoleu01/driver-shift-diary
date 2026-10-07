import 'package:equatable/equatable.dart';

/// Время на часах без даты и пояса: `08:10`.
class ClockTime extends Equatable {
  const ClockTime(this.hour, this.minute)
    : assert(hour >= 0 && hour < 24),
      assert(minute >= 0 && minute < 60);

  final int hour;
  final int minute;

  @override
  List<Object?> get props => [hour, minute];

  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
