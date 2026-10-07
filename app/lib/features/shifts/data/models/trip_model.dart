import '../../domain/entities/payment_method.dart';
import '../../domain/entities/trip.dart';
import '../../domain/entities/trip_draft.dart';
import 'json_reader.dart';

final _hasOffset = RegExp(r'(Z|[+-]\d{2}:\d{2})$');

/// Момент времени из ответа сервера.
///
/// Строку без смещения `DateTime.parse` молча считает временем телефона — та же
/// поездка на двух телефонах оказалась бы в разное время. Поэтому такая строка
/// — ошибка ответа, а не повод угадывать пояс.
DateTime parseInstant(String text) {
  if (!_hasOffset.hasMatch(text)) {
    throw FormatException('Время без смещения', text);
  }
  return DateTime.parse(text).toUtc();
}

abstract final class TripModel {
  static Trip fromJson(Map<String, dynamic> json) => Trip(
    id: json.read<String>('id'),
    start: parseInstant(json.read<String>('start')),
    end: parseInstant(json.read<String>('end')),
    amount: json.read<int>('amount'),
    payment: PaymentMethod.fromWire(json.read<String>('payment')),
    commission: json.read<int>('commission'),
  );

  /// Тело запроса на добавление.
  ///
  /// Время уходит в UTC с буквой `Z`: сервер принимает любое смещение и сам
  /// относит поездку к дню по своему поясу. `toUtc()` здесь обязателен — у
  /// местного времени `toIso8601String()` смещение не пишет вовсе.
  static Map<String, Object?> draftToJson(TripDraft draft) => {
    'id': draft.id,
    'start': draft.start.toUtc().toIso8601String(),
    'end': draft.end.toUtc().toIso8601String(),
    'amount': draft.amount,
    'payment': draft.payment.wire,
    'commission': draft.commission,
  };
}
