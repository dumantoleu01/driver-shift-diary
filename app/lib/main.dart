import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/di/injection.dart';
import 'features/drivers/presentation/cubit/drivers_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Названия дней и месяцев для заголовка дня.
  await initializeDateFormatting('ru');
  await configureDependencies();
  // Водитель выбирается до первого кадра: первый же запрос к серверу должен
  // уйти от его имени, а не в общий дневник.
  await getIt<DriversCubit>().load();
  runApp(const ShiftDiaryApp());
}
