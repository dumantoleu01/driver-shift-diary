import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shift_diary/core/theme/app_theme.dart';
import 'package:shift_diary/l10n/app_localizations.dart';

/// Названия дней и месяцев — один раз на файл с тестами экранов.
Future<void> loadDateSymbols() => initializeDateFormatting('ru');

const _delegates = <LocalizationsDelegate<Object>>[
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// Экран в том же окружении, что и в приложении: тема, русские тексты.
Widget testApp({Widget? home, RouterConfig<Object>? router}) => router != null
    ? MaterialApp.router(
        theme: AppTheme.light,
        locale: const Locale('ru'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: _delegates,
        routerConfig: router,
      )
    : MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('ru'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: _delegates,
        home: home,
      );

/// Экран телефона: в окне теста по умолчанию (800×600) вёрстка была бы
/// планшетной, и переполнение на узком экране осталось бы незамеченным.
void usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}
