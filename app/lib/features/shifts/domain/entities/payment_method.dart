/// Способ оплаты поездки.
enum PaymentMethod {
  cash('cash'),
  card('card');

  const PaymentMethod(this.wire);

  /// Как способ оплаты называется в API.
  final String wire;

  static PaymentMethod fromWire(String value) => values.firstWhere(
    (method) => method.wire == value,
    orElse: () => throw FormatException('Неизвестный способ оплаты', value),
  );
}
