import 'dart:async';
abstract class UseCase<T extends Object?> {

  abstract final String id;

  const UseCase();

  FutureOr<T> execute( Map<String, dynamic>? args );
}
