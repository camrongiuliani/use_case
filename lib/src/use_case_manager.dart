import 'dart:async';
import 'package:use_case/src/use_case_registry.dart';
import 'package:use_case/src/use_case_subscription.dart';
import 'package:use_case/use_case.dart';

class UseCaseManager {
  final UseCaseRegistry _registry;
  final UseCaseExecutor _executor;
  final bool debug;

  UseCaseManager({this.debug = false})
      : _registry = UseCaseRegistry(),
        _executor = UseCaseExecutor(debug: debug);

  /// Registers a UseCase
  registerUseCase(covariant UseCase useCase) {
    _registry.register(useCase);
  }

  bool useCaseExists(String id) => _registry.exists(id);

  Future<void> call(
    String id, {
    UseCaseObserver? observer,
    dynamic args,
  }) async {
    return _executor.add(_registry.getUseCase(id), observer, args);
  }

  Future<void> invoke(
    covariant UseCase useCase, {
    UseCaseObserver? observer,
    dynamic args,
  }) async {
    return _executor.add(useCase, observer, args);
  }

  UseCaseSubscription subscribe(String id, UseCaseObserver observer) {
    return _executor.subscribe(_registry.getUseCase(id), observer);
  }

  Future callFuture(String id, [dynamic args]) {
    Completer completer = Completer();

    UseCaseHandler handler = UseCaseHandler(onUpdate: (status) {
      if (status.state == UseCaseState.done) {
        completer.complete(status.data);
      } else if (status.state == UseCaseState.error) {
        completer.completeError(status.error ?? status, status.stackTrace);
      }
    });

    call(id, observer: handler, args: args);

    return completer.future;
  }

  Stream callStream(String id, [dynamic args]) {
    StreamController sc = StreamController();

    UseCaseHandler handler = UseCaseHandler(onUpdate: (status) {
      if (status.state == UseCaseState.done) {
        sc.sink.add(status.data);
        sc.close();
      } else if (status.state == UseCaseState.error) {
        sc.sink.addError(status.error ?? status, status.stackTrace);
        sc.close();
      }
    });

    sc.onListen = () {
      call(id, observer: handler, args: args);
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
