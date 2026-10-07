/// Поля поездки, под которыми форма показывает ошибку.
enum TripField {
  start('start'),
  end('end'),
  amount('amount'),
  payment('payment'),
  commission('commission');

  const TripField(this.wire);

  /// Как поле называется в ответе сервера (`error.fields`).
  final String wire;

  static TripField? fromWire(String name) {
    for (final field in values) {
      if (field.wire == name) return field;
    }
    return null;
  }
}

/// Коды причин — те же, что отдаёт сервер (`Violation` в `domain/rules.py`).
///
/// Приложение проверяет форму до отправки теми же правилами и теми же кодами,
/// поэтому текст под полем один и тот же, кто бы ни нашёл ошибку. Последнее
/// слово всё равно за сервером: его отказ показывается так же.
abstract final class FieldCodes {
  static const required = 'required';
  static const invalidType = 'invalid_type';
  static const outOfRange = 'out_of_range';
  static const mustBeAfterStart = 'must_be_after_start';
  static const mustBePositive = 'must_be_positive';
  static const tooLarge = 'too_large';
  static const mustNotBeNegative = 'must_not_be_negative';
  static const mustNotExceedAmount = 'must_not_exceed_amount';
}

/// Наибольшая сумма поездки, которую принимает сервер.
const maxTripAmount = 100000000;

final _digits = RegExp(r'^\d{1,12}$');

/// Целое число из поля формы; `null`, если там не число.
///
/// Пробелы между разрядами допускаются — так суммы пишут от руки. Запятая и
/// точка не допускаются: деньги в приложении только целые, и «2400,50» молча
/// не округляется.
int? parseWholeNumber(String text) {
  final compact = text.replaceAll(RegExp(r'[\s ]'), '');
  return _digits.hasMatch(compact) ? int.parse(compact) : null;
}

/// Проверить форму поездки: поле → код причины. Пусто — можно отправлять.
///
/// Возвращаются все нарушения сразу, чтобы водитель не исправлял их по одному.
Map<TripField, String> checkTripForm({
  required DateTime start,
  required DateTime end,
  required String amountText,
  required String commissionText,
}) {
  final found = <TripField, String>{};

  if (!end.isAfter(start)) {
    found[TripField.end] = FieldCodes.mustBeAfterStart;
  }

  final amount = parseWholeNumber(amountText);
  if (amountText.trim().isEmpty) {
    found[TripField.amount] = FieldCodes.required;
  } else if (amount == null) {
    found[TripField.amount] = FieldCodes.invalidType;
  } else if (amount <= 0) {
    found[TripField.amount] = FieldCodes.mustBePositive;
  } else if (amount > maxTripAmount) {
    found[TripField.amount] = FieldCodes.tooLarge;
  }

  final commission = parseWholeNumber(commissionText);
  if (commissionText.trim().isEmpty) {
    found[TripField.commission] = FieldCodes.required;
  } else if (commission == null) {
    found[TripField.commission] = FieldCodes.invalidType;
  } else if (amount != null &&
      !found.containsKey(TripField.amount) &&
      commission > amount) {
    // С негодной суммой сравнивать комиссию не с чем.
    found[TripField.commission] = FieldCodes.mustNotExceedAmount;
  }

  return found;
}

/// Комиссия, которую форма подставляет сама: [percent]% суммы, с округлением
/// до целого. Считается в целых числах — без `double`.
int suggestCommission(int amount, int percent) =>
    (amount * percent + 50) ~/ 100;
