import '../../../../core/time/calendar_day.dart';
import '../../domain/entities/day_report.dart';
import '../../domain/entities/day_summary.dart';
import 'json_reader.dart';
import 'trip_model.dart';

abstract final class DayReportModel {
  static DayReport fromJson(Map<String, dynamic> json) => DayReport(
    day: CalendarDay.parse(json.read<String>('date')),
    summary: _summary(json.readObject('summary')),
    trips: json.readObjects('trips').map(TripModel.fromJson).toList(),
  );

  static DaySummary _summary(Map<String, dynamic> json) {
    final byPayment = json.readObject('by_payment');
    return DaySummary(
      trips: json.read<int>('trips'),
      revenue: json.read<int>('revenue'),
      commission: json.read<int>('commission'),
      net: json.read<int>('net'),
      cash: _totals(byPayment.readObject('cash')),
      card: _totals(byPayment.readObject('card')),
    );
  }

  static PaymentTotals _totals(Map<String, dynamic> json) => PaymentTotals(
    trips: json.read<int>('trips'),
    amount: json.read<int>('amount'),
  );
}
