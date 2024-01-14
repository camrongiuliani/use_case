import 'package:freezed_annotation/freezed_annotation.dart';

part 'use_case_status.freezed.dart';

enum UseCaseState {
  none,
  queued,
  started,
  waiting,
  done,
  error,
}

@freezed
class UseCaseStatus<T> with _$UseCaseStatus<T> {
  const factory UseCaseStatus(
    Type type, {
    @Default(UseCaseState.none) UseCaseState state,
    T? data,
    Object? error,
    StackTrace? stackTrace,
  }) = _UseCaseStatus<T>;
}
