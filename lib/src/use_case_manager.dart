import 'dart:async';
import 'package:use_case/src/use_case_registry.dart';
import 'package:use_case/use_case.dart';

typedef UseCaseBuilder<T extends UseCase> = T Function();

class UseCaseManager {
  final UseCaseRegistry _registry;
  final UseCaseExecutor _executor;
  final bool debug;

  UseCaseManager({this.debug = false})
      : _registry = UseCaseRegistry(),
        _executor = UseCaseExecutor(debug: debug);

  bool get isExecuting => _executor.queueLength > 0;

  /// Registers a UseCase
  register<T extends UseCase>(UseCaseBuilder<T> builder) {
    _registry.register<T>(builder);
  }

  // registerEvent<X, T extends UseCase>(T Function() builder) {
  //
  // }

  bool useCaseExists<T extends UseCase>() => _registry.exists<T>();

  Future<void> call<T extends UseCase>({
    UseCaseObserver? observer,
    dynamic args,
  }) async {
    return _executor.add<T>(_registry.buildUseCase<T>(), observer, args);
  }

  Future<void> invoke(
    covariant UseCase useCase, {
    UseCaseObserver? observer,
    dynamic args,
  }) async {
    return _executor.add(useCase, observer, args);
  }

  UseCaseSubscription subscribe<T extends UseCase>(UseCaseObserver observer) {
    return _executor.subscribe<T>(observer);
  }

  Future callFuture<T extends UseCase>([dynamic args]) {
    Completer completer = Completer();

    UseCaseHandler handler = UseCaseHandler(
      onUpdate: (status) {
        if (status.state == UseCaseState.done) {
          completer.complete(status.data);
        } else if (status.state == UseCaseState.error) {
          completer.completeError(status.error ?? status, status.stackTrace);
        }
      },
    );

    call<T>(observer: handler, args: args);

    return completer.future;
  }

  Stream callStream<T extends UseCase>([dynamic args]) {
    StreamController sc = StreamController();

    UseCaseHandler handler = UseCaseHandler(
      onUpdate: (status) {
        if (status.state == UseCaseState.done) {
          sc.sink.add(status.data);
          sc.close();
        } else if (status.state == UseCaseState.error) {
          sc.sink.addError(status.error ?? status, status.stackTrace);
          sc.close();
        }
      },
    );

    sc.onListen = () {
      call<T>(observer: handler, args: args);
    };

    sc.onCancel = () {
      if (!sc.hasListener) {
        sc.close();
      }
    };

    return sc.stream.asBroadcastStream();
  }

  Future<void> flush() async {
    await _registry.flush();
    await _executor.flush();
  }
}
