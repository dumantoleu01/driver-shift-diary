import 'package:equatable/equatable.dart';

import 'payment_method.dart';

/// Поездка водителя.
///
/// [start] и [end] — моменты времени в UTC. Какое это время на часах водителя,
/// решает `ServiceZone`: сама поездка про пояса ничего не знает.
class Trip extends Equatable {
  const Trip({
    required this.id,
    required this.start,
    required this.end,
    required this.amount,
    required this.payment,
    required this.commission,
  });

  final String id;
  final DateTime start;
  final DateTime end;

  /// Сумма поездки целым числом — дробные деньги в приложении не появляются.
  final int amount;
  final PaymentMethod payment;
  final int commission;

  /// Сколько водитель получает за поездку «на руки».
  int get net => amount - commission;

  Duration get duration => end.difference(start);

  @override
  List<Object?> get props => [id, start, end, amount, payment, commission];
}
