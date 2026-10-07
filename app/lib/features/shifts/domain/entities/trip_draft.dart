import 'package:equatable/equatable.dart';

import 'payment_method.dart';
import 'trip.dart';

/// Поездка, которую приложение отправляет на сервер.
///
/// [id] назначает клиент, и назначает один раз — когда открывается форма. Если
/// ответ потеряется по дороге, повтор уйдёт с тем же `id`, и сервер узнает в
/// нём ту же поездку, а не запишет вторую.
class TripDraft extends Equatable {
  const TripDraft({
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
  final int amount;
  final PaymentMethod payment;
  final int commission;

  @override
  List<Object?> get props => [id, start, end, amount, payment, commission];
}

/// Ответ сервера на добавление поездки.
class AddedTrip extends Equatable {
  const AddedTrip({required this.trip, required this.created});

  /// Поездка в том виде, в каком она записана на сервере.
  final Trip trip;

  /// `false` — такая поездка уже была записана, новой записи не появилось.
  /// Для приложения это тоже успех.
  final bool created;

  @override
  List<Object?> get props => [trip, created];
}
