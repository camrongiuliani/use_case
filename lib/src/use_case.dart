import 'dart:async';

abstract class UseCase<T extends Object?> {
  const UseCase();

  FutureOr<T> execute(covariant Object? args);

  Future<void> dispose() async {}

  bool get allowConcurrency => false;
}
