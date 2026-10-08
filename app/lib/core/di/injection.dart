import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../features/drivers/data/datasources/drivers_local_datasource.dart';
import '../../features/drivers/data/repositories/drivers_repository_impl.dart';
import '../../features/drivers/domain/repositories/drivers_repository.dart';
import '../../features/drivers/domain/usecases/create_driver.dart';
import '../../features/drivers/domain/usecases/load_drivers.dart';
import '../../features/drivers/domain/usecases/rename_driver.dart';
import '../../features/drivers/domain/usecases/select_driver.dart';
import '../../features/drivers/presentation/cubit/drivers_cubit.dart';
import '../../features/shifts/data/datasources/shifts_remote_datasource.dart';
import '../../features/shifts/data/repositories/shifts_repository_impl.dart';
import '../../features/shifts/domain/repositories/shifts_repository.dart';
import '../../features/shifts/domain/usecases/add_trip.dart';
import '../../features/shifts/domain/usecases/get_day_report.dart';
import '../../features/shifts/domain/usecases/get_diary_index.dart';
import '../../features/shifts/presentation/cubit/day_cubit.dart';
import '../../features/shifts/presentation/cubit/trip_form_cubit.dart';
import '../config/app_config.dart';
import '../network/api_client.dart';
import '../router/app_router.dart';
import '../session/current_driver.dart';

final getIt = GetIt.instance;

/// Зависимости регистрируются руками: их полтора десятка, и кодогенерация ради
/// них добавила бы шаг сборки, не убрав ни одной строки.
Future<void> configureDependencies() async {
  final prefs = await SharedPreferences.getInstance();

  getIt
    // Один объект на приложение: сеть подписывает им запросы, выбор водителя
    // его меняет.
    ..registerSingleton(CurrentDriver())
    ..registerLazySingleton<ApiClient>(
      () => ApiClient(
        Dio(ApiClient.options(AppConfig.apiBaseUrl)),
        driverId: () => getIt<CurrentDriver>().id,
      ),
    )
    // --- водители ---
    ..registerLazySingleton<DriversLocalDataSource>(
      () => DriversLocalDataSourceImpl(prefs),
    )
    ..registerLazySingleton<DriversRepository>(
      () => DriversRepositoryImpl(
        local: getIt<DriversLocalDataSource>(),
        session: getIt<CurrentDriver>(),
        newId: () => const Uuid().v4(),
      ),
    )
    ..registerLazySingleton(() => LoadDrivers(getIt<DriversRepository>()))
    ..registerLazySingleton(() => CreateDriver(getIt<DriversRepository>()))
    ..registerLazySingleton(() => SelectDriver(getIt<DriversRepository>()))
    ..registerLazySingleton(() => RenameDriver(getIt<DriversRepository>()))
    // Кубит водителей один на всё время работы: он читается до первого запроса
    // к серверу и живёт над навигацией.
    ..registerLazySingleton(
      () => DriversCubit(
        getIt<LoadDrivers>(),
        getIt<CreateDriver>(),
        getIt<SelectDriver>(),
        getIt<RenameDriver>(),
      ),
    )
    // --- дневник ---
    ..registerLazySingleton<ShiftsRemoteDataSource>(
      () => ShiftsRemoteDataSourceImpl(getIt<ApiClient>()),
    )
    ..registerLazySingleton<ShiftsRepository>(
      () => ShiftsRepositoryImpl(
        remoteDataSource: getIt<ShiftsRemoteDataSource>(),
      ),
    )
    ..registerLazySingleton(() => GetDiaryIndex(getIt<ShiftsRepository>()))
    ..registerLazySingleton(() => GetDayReport(getIt<ShiftsRepository>()))
    ..registerLazySingleton(() => AddTrip(getIt<ShiftsRepository>()))
    ..registerFactory(
      () => DayCubit(getIt<GetDiaryIndex>(), getIt<GetDayReport>()),
    )
    // Новая форма — новый `id` поездки. Он создаётся здесь, один раз на форму,
    // и дальше не меняется, сколько бы раз её ни отправляли.
    ..registerFactoryParam<TripFormCubit, TripFormArgs, void>(
      (args, _) => TripFormCubit(
        getIt<AddTrip>(),
        zone: args.zone,
        day: args.day,
        tripId: const Uuid().v4(),
      ),
    );
}
