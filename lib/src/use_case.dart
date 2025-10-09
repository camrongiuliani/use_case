import 'dart:async';

import 'package:uuid/uuid.dart';

abstract class UseCase<GIVEN extends Object?, RESULT> {
  UseCase() : traceId = const Uuid().v4();

  final String traceId;

  FutureOr<RESULT> execute(GIVEN args);

  Future<void> dispose() async {}

  bool get allowConcurrency => false;
}
