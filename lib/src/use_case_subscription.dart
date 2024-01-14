import 'package:use_case/use_case.dart';

class UseCaseSubscription<T extends UseCase> {
  late final Type type;
  final UseCaseObserver observer;
  final UseCaseExecutor _exe;

  UseCaseSubscription(this.observer, this._exe) {
    type = T;
  }

  bool get disposed => !_exe.hasSubscription(this);

  dispose() => _exe.unsubscribe(this);
}
