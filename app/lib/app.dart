import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/di/injection.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/drivers/presentation/cubit/drivers_cubit.dart';
import 'features/shifts/presentation/cubit/day_cubit.dart';
import 'l10n/app_localizations.dart';

class ShiftDiaryApp extends StatelessWidget {
  const ShiftDiaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Кубит дня живёт над навигацией: форма поездки открывается поверх главного
    // экрана, а после неё тот же кубит показывает день добавленной поездки.
    return MultiBlocProvider(
      providers: [
        // Уже прочитан в main() и живёт всё время работы — поэтому value.
        BlocProvider.value(value: getIt<DriversCubit>()),
        BlocProvider(create: (_) => getIt<DayCubit>()..start()),
      ],
      child: MaterialApp.router(
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        routerConfig: AppRouter.router,
        locale: const Locale('ru'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // Время в приложении — всегда 24 часа, как в самих поездках, какой бы
        // формат ни стоял в настройках телефона.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
      ),
    );
  }
}
