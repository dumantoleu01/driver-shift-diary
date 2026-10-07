import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/time/calendar_day.dart';
import '../../domain/entities/day_report.dart';
import '../../domain/entities/diary_index.dart';
import '../../domain/entities/trip_draft.dart';
import '../models/day_report_model.dart';
import '../models/diary_index_model.dart';
import '../models/json_reader.dart';
import '../models/trip_model.dart';

abstract class ShiftsRemoteDataSource {
  /// `GET /api/days`
  Future<DiaryIndex> getIndex();

  /// `GET /api/days/{день}`
  Future<DayReport> getDayReport(CalendarDay day);

  /// `POST /api/trips`. `201` — поездка создана, `200` — такая уже записана.
  ///
  /// Бросает [TripRejectedException] на `422` и [TripIdConflictException] на
  /// `409`: это разные ситуации с разными действиями, а не «ошибка сервера».
  Future<AddedTrip> addTrip(TripDraft draft);
}

class ShiftsRemoteDataSourceImpl implements ShiftsRemoteDataSource {
  ShiftsRemoteDataSourceImpl(this._api);

  final ApiClient _api;

  @override
  Future<DiaryIndex> getIndex() async {
    final response = await _api.get('/api/days');
    return _parse(response.data, DiaryIndexModel.fromJson);
  }

  @override
  Future<DayReport> getDayReport(CalendarDay day) async {
    final response = await _api.get('/api/days/${day.toIso()}');
    return _parse(response.data, DayReportModel.fromJson);
  }

  @override
  Future<AddedTrip> addTrip(TripDraft draft) async {
    final ApiResponse response;
    try {
      response = await _api.post('/api/trips', TripModel.draftToJson(draft));
    } on ServerException catch (e) {
      if (e.statusCode == 422 && e.fields.isNotEmpty) {
        throw TripRejectedException(e.fields);
      }
      if (e.statusCode == 409) throw TripIdConflictException();
      rethrow;
    }
    return AddedTrip(
      trip: _parse(response.data, TripModel.fromJson),
      created: response.statusCode == 201,
    );
  }

  /// Ответ не того вида — отдельное исключение, а не `TypeError` из глубины
  /// разбора: повтор запроса тут не поможет, и текст для водителя другой.
  T _parse<T>(Object? data, T Function(Map<String, dynamic>) fromJson) {
    try {
      return fromJson(asJsonObject(data));
    } on FormatException catch (e) {
      throw UnexpectedResponseException(e.message);
    }
  }
}
