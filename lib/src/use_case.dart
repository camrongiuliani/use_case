import 'dart:async';

abstract class UseCase<GIVEN extends Object?, RESULT> {
  const UseCase();

  FutureOr<RESULT> execute(GIVEN args);

  Future<void> dispose() async {}

  bool get allowConcurrency => false;
}
