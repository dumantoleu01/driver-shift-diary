import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/di/injection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Названия дней и месяцев для заголовка дня.
  await initializeDateFormatting('ru');
  configureDependencies();
  runApp(const ShiftDiaryApp());
}
