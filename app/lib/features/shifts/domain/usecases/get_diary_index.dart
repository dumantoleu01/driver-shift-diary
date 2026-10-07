import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/diary_index.dart';
import '../repositories/shifts_repository.dart';

class GetDiaryIndex implements UseCase<DiaryIndex, NoParams> {
  GetDiaryIndex(this.repository);

  final ShiftsRepository repository;

  @override
  Future<Either<Failure, DiaryIndex>> call(NoParams params) =>
      repository.getIndex();
}
