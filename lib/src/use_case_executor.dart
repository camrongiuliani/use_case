import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:synchronized/synchronized.dart';
import 'package:use_case/use_case.dart';

class UseCaseExecutor {
  final List<_UseCaseWrapper> _queue = [];
  final Map<Type, List<UseCaseSubscription>> _subscriptions = {};
  final Lock _executionLock;
  final Lock _notificationLock;
  final bool debug;

  static UseCaseExecutor? instance;

  UseCaseExecutor._(this._notificationLock, this._executionLock, this.debug);

  factory UseCaseExecutor({bool debug = false}) {
    return instance ??= UseCaseExecutor._(
      Lock(
        reentrant: true,
      ),
      Lock(
        reentrant: true,
      ),
      debug,
    );
  }

  int get queueLength => _queue.length;

  void log(String message) {
    if (kDebugMode && debug) {
      debugPrint('UseCaseExecutor: $message');
    }
  }

  void _notifyObservers(UseCaseStatus status, List<UseCaseObserver> observers) {
    _notificationLock.synchronized(() {
      for (var observer in observers) {
        observer.onUseCaseUpdate(status);
      }
    });
  }

  Future<void> flush() async {
    return _executionLock.synchronized(() {
      _queue.clear();
      _subscriptions.clear();
    });
  }

  Future<void> _runQueue() async {
    if (_queue.isEmpty) {
      return;
    }

    return _executionLock.synchronized(() async {
      log('Queue Length: ${_queue.length}');

      List<Completer<void>> completion = [];

      for (var entry
          in _queue.where((e) => e.status.state == UseCaseState.queued)) {
        if (entry.status.state != UseCaseState.queued) {
          continue;
        }

        Completer<void> completer = Completer();

        completion.add(completer);

        var useCase = entry.useCase;
        var args = entry.args;
        var observers = entry.observers;
        var type = entry.type;

        if (_subscriptions.containsKey(type)) {
          observers.addAll(_subscriptions[type]!.map((e) => e.observer));
        }

        entry.status = entry.status.copyWith(state: UseCaseState.started);
        _notifyObservers(entry.status, observers);

        Future.sync(() async {
          log('${useCase.runtimeType} Starting Execution *****');
          try {
            var r = await useCase.execute(args);
            await useCase.dispose();
            return r;
          } catch (e) {
            try {
              await useCase.dispose();
            } catch (e) {
              log(e.toString());
            }

            rethrow;
          }
        }).then((val) {
          entry.status =
              entry.status.copyWith(state: UseCaseState.done, data: val);

          log('${useCase.runtimeType} Completed Normally');

          _notifyObservers(entry.status, observers);

          completer.complete();
          log('${useCase.runtimeType} Finished Execution*****');
        }).onError((error, stackTrace) {
          entry.status = entry.status.copyWith(
              state: UseCaseState.error, error: error, stackTrace: stackTrace);

          log('${useCase.runtimeType} Completed With Error');

          _notifyObservers(entry.status, observers);

          completer.complete();
          log('${useCase.runtimeType} Finished Execution*****');
        });

        entry.status = entry.status.copyWith(state: UseCaseState.waiting);
        _notifyObservers(entry.status, observers);
      }

      return await Future.wait(completion.map((e) => e.future));
    }).then((v) async {
      _queue.removeWhere((uc) {
        bool remove =
            [UseCaseState.done, UseCaseState.error].contains(uc.status.state);

        if (remove) {
          log('Removed ${uc.runtimeType} from the queue');
        }

        return remove;
      });

      if (_queue.isNotEmpty) {
        return await _runQueue();
      }
    }).onError((error, stackTrace) {
      log('Error -> ${error?.toString()}');
    });
  }

  UseCaseSubscription subscribe<T extends UseCase>(UseCaseObserver observer) {
    var sub = UseCaseSubscription<T>(observer, this);

    (_subscriptions[T] ??= []).add(sub);

    return sub;
  }

  void unsubscribe(UseCaseSubscription sub) {
    _subscriptions[sub.type]?.remove(sub);
  }

  bool hasSubscription(UseCaseSubscription sub) {
    return _subscriptions.containsKey(sub.type) &&
        _subscriptions[sub.type]!.contains(sub);
  }

  void broadcast<T extends UseCase>(T useCase, [dynamic args]) {
    assert(() {
      return _subscriptions.keys.contains(T) && _subscriptions[T]!.isNotEmpty;
    }(), 'Requested broadcast for UseCase $T, which had no subscriptions');

    _subscriptions[T]!.map(
      (e) => add(
        useCase,
        UseCaseHandler(
          onUpdate: (_) {},
        ),
        args,
      ),
    );
  }

  void add<T extends UseCase>(T uc, UseCaseObserver? observer, [dynamic args]) {
    // Check UseCase exists with matching args.
    var idx = _queue.indexWhere((q) => q.isType<T>(args));

    // If not exists, add to queue.
    if (idx == -1 || uc.allowConcurrency) {
      log('${uc.runtimeType} added to the queue');
      _queue.add(_UseCaseWrapper<T>(uc, args, observer));
    } else if (observer != null) {
      // Otherwise grab the existing UseCase
      var existing = _queue[idx];

      // If the existing UseCase is done executing, just relay the status.
      if ([UseCaseState.done, UseCaseState.error]
          .contains(existing.status.state)) {
        log('${uc.runtimeType} used result of already completed UseCase');
        observer.onUseCaseUpdate(existing.status);
        return;
      }

      log('${uc.runtimeType} added as an observer to an already existing UseCase');

      // Otherwise, attach this observer to the existing UseCase
      existing.observers.add(observer);

      // observer.onUseCaseUpdate( existing.status );
    }

    if (!_executionLock.locked) {
      _runQueue();
    }
  }
}

class _UseCaseWrapper<T extends UseCase> {
  final T useCase;
  final dynamic args;
  late final Type type;
  late UseCaseStatus status;

  final List<UseCaseObserver> observers = [];

  _UseCaseWrapper(this.useCase, this.args, UseCaseObserver? observer) {
    type = T;
    status = UseCaseStatus(T, state: UseCaseState.queued);
    if (observer != null) {
      observers.add(observer);
      observer.onUseCaseUpdate(status);
    }
  }

  bool isType<X>(dynamic args) => X == T && args == this.args;
}
