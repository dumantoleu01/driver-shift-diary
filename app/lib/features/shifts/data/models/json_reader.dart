/// Чтение полей ответа с проверкой типа.
///
/// Ответ сервера не приводится к типу молча: `as int` на строке упал бы
/// `TypeError` где-то в глубине, а здесь ошибка называет поле. Число с дробной
/// частью на месте суммы — тоже ошибка, а не повод округлить.
extension JsonReader on Map<String, dynamic> {
  T read<T>(String key) {
    final value = this[key];
    if (value is T) return value;
    throw FormatException(
      'Поле "$key": ожидается $T, пришло ${value.runtimeType}',
    );
  }

  Map<String, dynamic> readObject(String key) {
    final value = this[key];
    if (value is Map<String, dynamic>) return value;
    throw FormatException('Поле "$key": ожидается объект');
  }

  List<Map<String, dynamic>> readObjects(String key) {
    final value = this[key];
    if (value is List && value.every((item) => item is Map<String, dynamic>)) {
      return value.cast<Map<String, dynamic>>();
    }
    throw FormatException('Поле "$key": ожидается список объектов');
  }
}

/// Тело ответа как объект JSON.
Map<String, dynamic> asJsonObject(Object? data) {
  if (data is Map<String, dynamic>) return data;
  throw FormatException('Ожидается объект JSON, пришло ${data.runtimeType}');
}
