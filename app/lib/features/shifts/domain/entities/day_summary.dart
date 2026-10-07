import 'package:equatable/equatable.dart';

/// Итог по одному способу оплаты.
class PaymentTotals extends Equatable {
  const PaymentTotals({required this.trips, required this.amount});

  final int trips;
  final int amount;

  @override
  List<Object?> get props => [trips, amount];
}

/// Сводка за день.
///
/// Считает её сервер, приложение только показывает: два независимых расчёта
/// рано или поздно дали бы два разных итога.
class DaySummary extends Equatable {
  const DaySummary({
    required this.trips,
    required this.revenue,
    required this.commission,
    required this.net,
    required this.cash,
    required this.card,
  });

  final int trips;
  final int revenue;
  final int commission;

  /// «На руки»: выручка минус комиссия.
  final int net;
  final PaymentTotals cash;
  final PaymentTotals card;

  @override
  List<Object?> get props => [trips, revenue, commission, net, cash, card];
}
