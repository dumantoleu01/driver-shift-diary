import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:uuid/uuid.dart';

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

final getIt = GetIt.instance;

/// Зависимости регистрируются руками: их десяток, и кодогенерация ради них
/// добавила бы шаг сборки, не убрав ни одной строки.
void configureDependencies() {
  getIt
    ..registerLazySingleton<ApiClient>(
      () => ApiClient(Dio(ApiClient.options(AppConfig.apiBaseUrl))),
    )
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
