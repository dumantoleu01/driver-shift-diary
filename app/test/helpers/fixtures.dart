import 'package:shift_diary/core/time/calendar_day.dart';
import 'package:shift_diary/core/time/service_zone.dart';
import 'package:shift_diary/features/shifts/domain/entities/day_report.dart';
import 'package:shift_diary/features/shifts/domain/entities/day_summary.dart';
import 'package:shift_diary/features/shifts/domain/entities/diary_index.dart';
import 'package:shift_diary/features/shifts/domain/entities/payment_method.dart';
import 'package:shift_diary/features/shifts/domain/entities/trip.dart';

/// Пояс сервиса из образца данных.
const zone = ServiceZone(Duration(hours: 5));

const sep29 = CalendarDay(2026, 9, 29);
const sep30 = CalendarDay(2026, 9, 30);
const oct1 = CalendarDay(2026, 10, 1);
const oct2 = CalendarDay(2026, 10, 2);
const oct4 = CalendarDay(2026, 10, 4);

/// Поездка `t1` из текста задания: 08:10–08:32 по времени сервиса.
final t1 = Trip(
  id: 't1',
  start: DateTime.utc(2026, 10, 1, 3, 10),
  end: DateTime.utc(2026, 10, 1, 3, 32),
  amount: 2400,
  payment: PaymentMethod.card,
  commission: 360,
);

/// Поездка `t2` из текста задания: 09:05–09:20, наличные.
final t2 = Trip(
  id: 't2',
  start: DateTime.utc(2026, 10, 1, 4, 5),
  end: DateTime.utc(2026, 10, 1, 4, 20),
  amount: 1500,
  payment: PaymentMethod.cash,
  commission: 225,
);

/// Сводка, посчитанная так, как её считает сервер.
DaySummary summaryOf(List<Trip> trips) {
  PaymentTotals totals(PaymentMethod payment) {
    final paid = trips.where((trip) => trip.payment == payment);
    return PaymentTotals(
      trips: paid.length,
      amount: paid.fold(0, (sum, trip) => sum + trip.amount),
    );
  }

  final revenue = trips.fold(0, (sum, trip) => sum + trip.amount);
  final commission = trips.fold(0, (sum, trip) => sum + trip.commission);
  return DaySummary(
    trips: trips.length,
    revenue: revenue,
    commission: commission,
    net: revenue - commission,
    cash: totals(PaymentMethod.cash),
    card: totals(PaymentMethod.card),
  );
}

DayReport reportOf(CalendarDay day, [List<Trip> trips = const []]) =>
    DayReport(day: day, summary: summaryOf(trips), trips: trips);

DiaryIndex indexOf(List<CalendarDay> days) => DiaryIndex(
  zone: zone,
  days: [for (final day in days) DayEntry(day: day, trips: 1)],
);
