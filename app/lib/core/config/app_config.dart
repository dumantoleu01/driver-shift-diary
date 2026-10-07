import 'package:flutter/foundation.dart';

/// Настройки сборки.
abstract final class AppConfig {
  static const _definedBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Адрес сервера. Задаётся при сборке:
  /// `--dart-define=API_BASE_URL=https://example.com`.
  ///
  /// Без него приложение идёт на сервер, запущенный на машине разработчика:
  /// эмулятор Android видит её как `10.0.2.2`, симулятор iOS — как `127.0.0.1`.
  static String get apiBaseUrl {
    if (_definedBaseUrl.isNotEmpty) return _definedBaseUrl;
    return defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:8000'
        : 'http://127.0.0.1:8000';
  }

  /// Знак валюты рядом с суммами.
  static const currencySign = '₸';

  /// Какую комиссию форма подставляет сама, пока водитель не ввёл свою.
  /// В образце данных комиссия везде равна 15% суммы.
  static const defaultCommissionPercent = 15;
}
