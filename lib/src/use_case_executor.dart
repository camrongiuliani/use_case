import 'dart:async';
import 'package:synchronized/synchronized.dart';
import 'package:use_case/use_case.dart';

typedef UCLogger = void Function(String message, UCLogLevel logLevel);

/// Thrown when a batch of queued UseCases exceeds [UseCaseExecutor.batchTimeout]
/// and the executor abandons it.
///
/// The UseCase itself cannot be cancelled, so it keeps running; the executor
/// simply stops waiting on it and discards whatever it eventually produces.
/// Observers are notified with [UseCaseState.error] carrying this exception,
/// which is what lets a consumer tell "abandoned by the executor" apart from a
/// genuine failure inside the UseCase.
class UseCaseTimeoutException implements Exception {
  UseCaseTimeoutException(this.useCaseType, this.timeout);

  /// The type of the UseCase that was abandoned.
  final Type useCaseType;

  /// The batch timeout that elapsed.
  final Duration timeout;

  @override
  String toString() {
    return 'UseCaseTimeoutException: $useCaseType was abandoned after its batch '
        'exceeded $timeout. The UseCase may still be running.';
  }
}

class UseCaseExecutor {
  final List<_UseCaseWrapper> _queue = [];
  final Map<Type, List<UseCaseSubscription>> _subscriptions = {};
  final Lock _executionLock;
  final Lock _notificationLock;
  final bool debug;
  final UCLogger? logger;

  /// Maximum time a single batch of queued UseCases is allowed to run before
  /// the batch is abandoned.
  ///
  /// The in-flight UseCases cannot be cancelled, so they keep running; the
  /// executor simply stops waiting on them, releases the execution lock and
  /// resumes draining the queue.
  ///
  /// Observers of an abandoned UseCase are notified with [UseCaseState.error]
  /// carrying a [UseCaseTimeoutException], and the entry leaves the queue. If
  /// the abandoned UseCase later completes, its result is discarded and no
  /// further notification is sent.
  ///
  /// Two known rough edges on this path:
  ///
  /// * The timeout status carries no `stackTrace`, so a consumer bridging it to
  ///   a Future (such as `UseCaseManager.callFuture`) completes the error with a
  ///   null stack trace.
  /// * `dispose()` still runs on the abandoned UseCase whenever it eventually
  ///   finishes, which is after its observers were told the run had ended.
  final Duration batchTimeout;

  static UseCaseExecutor? instance;

  final DartValueNotifier<bool> isExecuting = DartValueNotifier(false);

  UseCaseExecutor._(
    this._notificationLock,
    this._executionLock,
    this.debug,
    this.logger, [
    this.batchTimeout = const Duration(seconds: 60),
  ]);

  /// Returns the process-wide [UseCaseExecutor] singleton.
  ///
  /// NOTE: the instance is created once and cached in [instance]. Every
  /// parameter, including [batchTimeout], is therefore only applied on the
  /// FIRST call. Later calls return the existing instance and ignore the values
  /// passed to them. Configure the executor before anything else constructs it,
  /// or reset [instance] yourself.
  ///
  /// A later call that explicitly passes a [batchTimeout] differing from the
  /// live instance's logs a warning, so a dropped configuration is visible
  /// rather than silent. Omitting [batchTimeout] is not a configuration attempt
  /// and is never warned about. The other parameters are still dropped without
  /// a warning.
  ///
  /// The warning is sent to the live instance's logger AND, when it differs, to
  /// the logger passed to this call — otherwise a caller that configures the
  /// executor late would never see that its value was dropped, because the
  /// instance doing the logging is the one it failed to configure.
  factory UseCaseExecutor({
    bool debug = false,
    UCLogger? logger,
    Duration? batchTimeout,
  }) {
    final existing = instance;

    // `batchTimeout == null` means "not passed". Without the nullable type the
    // factory cannot tell that apart from an explicit 60s, and every default
    // construction after a configured one would be blamed for a value it never
    // supplied.
    if (existing != null &&
        batchTimeout != null &&
        existing.batchTimeout != batchTimeout) {
      final message =
          'UseCaseExecutor already exists, so the batchTimeout passed to this '
          'call ($batchTimeout) was IGNORED; the instance keeps '
          '${existing.batchTimeout}. Construct the executor with the timeout '
          'you want before anything else constructs it, or reset '
          'UseCaseExecutor.instance first.';

      existing.logW(message);

      // The live instance may have been built without a logger (UseCaseManager
      // builds it that way), which would send the warning nowhere. Tell the
      // caller directly too.
      if (logger != null && !identical(logger, existing.logger)) {
        logger(message, UCLogLevel.warning);
      }
    }

    return instance ??= UseCaseExecutor._(
      Lock(
        reentrant: true,
      ),
      Lock(
        reentrant: true,
      ),
      debug,
      logger,
      batchTimeout ?? const Duration(seconds: 60),
    );
  }

  void log(String message, UCLogLevel logLevel) {
    if (logger != null) {
      logger!(message, logLevel);
    } else if (debug) {
      // ignore: avoid_print
      print('UseCaseExecutor: $message');
    }
  }
  
  void logV(String message) => log(message, UCLogLevel.verbose);
  void logD(String message) => log(message, UCLogLevel.debug);
  void logI(String message) => log(message, UCLogLevel.info);
  void logW(String message) => log(message, UCLogLevel.warning);
  void logE(String message) => log(message, UCLogLevel.error);

  void _notifyObservers(UseCaseStatus status, List<UseCaseObserver> observers) {
    _notificationLock.synchronized(() {
      for (var observer in observers) {
        observer.onUseCaseUpdate(status);
      }
    });
  }

  Future<void> flush() async {
    List<_UseCaseWrapper> queueCopy = List.from(_queue);
    _queue.clear();

    for (var entry in queueCopy) {
      // Same reasoning as the batch timeout: the execution closures still hold
      // this entry, so without the flag the success arm would later overwrite
      // the status and notify `done` after `error`.
      entry.abandoned = true;

      entry.status = entry.status.copyWith(state: UseCaseState.error);
      _notifyObservers(entry.status, entry.observers);
    }

    _subscriptions.clear();
  }

  List<_UseCaseWrapper> _getQueue() {
    return _queue.where((e) {
      return e.status.state == UseCaseState.queued;
    }).toList();
  }

  Future<void> _runQueue() async {
    final queue = _getQueue();

    if (queue.isEmpty) {
      isExecuting.value = false;

      return;
    }

    isExecuting.value = true;

    return _executionLock.synchronized(() async {
      logV('Queue Length: ${queue.length}');

      List<Completer<void>> completion = [];

      for (var entry in queue) {
        if (entry.status.state != UseCaseState.queued) {
          continue;
        }

        if (queue.isEmpty) {
          entry.status = entry.status.copyWith(state: UseCaseState.error);
          _notifyObservers(entry.status, entry.observers);
          for (final completer in completion) {
            completer.completeError(
              'Queue was empty, requests likely cancelled',
            );
          }
          return null;
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
          logV('${useCase.runtimeType} Starting Execution ');
          try {
            var r = await useCase.execute(args);
            await useCase.dispose();
            logV('UseCaseExecutor: DISPOSED ${useCase.runtimeType}');
            return r;
          } catch (e) {
            logE('Error (1) in ${useCase.runtimeType}');
            try {
              await useCase.dispose();
            } catch (e) {
              logE('Error (2) in ${useCase.runtimeType} : ${e.toString()}');
            }

            logE('Error (3) in ${useCase.runtimeType}');

            rethrow;
          }
        }).then((val) {
          // The batch this UseCase belonged to timed out; observers have
          // already been given a terminal status, so drop the late result
          // rather than notifying a second time.
          if (entry.abandoned) {
            logV(
              '${useCase.runtimeType} completed after its batch was abandoned; '
              'result discarded',
            );

            if (!completer.isCompleted) {
              completer.complete();
            }
            return;
          }

          entry.status = entry.status.copyWith(
            state: UseCaseState.done,
            data: val,
          );

          logV('${useCase.runtimeType} Completed Normally');

          _notifyObservers(entry.status, observers);

          if (!completer.isCompleted) {
            completer.complete();
          }
          logV('${useCase.runtimeType} Finished Execution');
        }, onError: (Object error, StackTrace stackTrace) {
          logE('Error (4) in ${useCase.runtimeType} : ${error.toString()}');

          if (entry.abandoned) {
            logV(
              '${useCase.runtimeType} failed after its batch was abandoned; '
              'error discarded',
            );

            if (!completer.isCompleted) {
              completer.complete();
            }
            return;
          }

          entry.status = entry.status.copyWith(
            state: UseCaseState.error,
            error: error,
            stackTrace: stackTrace,
          );

          logE('${useCase.runtimeType} Completed With Error: $error');

          _notifyObservers(entry.status, observers);

          if (!completer.isCompleted) {
            completer.complete();
          }
          logV('${useCase.runtimeType} Finished Execution');
        });

        entry.status = entry.status.copyWith(state: UseCaseState.waiting);
        _notifyObservers(entry.status, observers);
      }

      // The timeout is applied INSIDE the synchronized block, on the batch
      // itself. Timing out therefore completes the block, which releases the
      // execution lock and lets the queue keep draining below.
      //
      // The in-flight UseCases cannot be cancelled, so they keep running, but
      // the executor has given up on them: each one is marked abandoned and
      // given a terminal `error` status carrying a UseCaseTimeoutException, so
      // its observers get an outcome instead of waiting forever. Being terminal
      // also makes cleanQueue() below reclaim the entry, which is what lets a
      // later add() of the same type dispatch a fresh run rather than attach to
      // the abandoned one. Late completion is discarded (see `abandoned` in the
      // handlers above).
      return Future.wait(completion.map((e) => e.future)).timeout(
        batchTimeout,
        onTimeout: () {
          logE('Timeout while executing UseCases');

          for (final entry in queue) {
            // Only the UseCases this batch actually dispatched and is still
            // waiting on. Anything already done/error keeps its real outcome.
            if (entry.status.state != UseCaseState.started &&
                entry.status.state != UseCaseState.waiting) {
              continue;
            }

            entry.abandoned = true;

            entry.status = entry.status.copyWith(
              state: UseCaseState.error,
              error: UseCaseTimeoutException(entry.type, batchTimeout),
            );

            logE('${entry.type} abandoned after $batchTimeout');

            _notifyObservers(entry.status, entry.observers);
          }

          return <void>[];
        },
      );
    }).then((v) async {
      cleanQueue();
      return _runQueue();
    }).onError((error, stackTrace) {
      logE('Error -> ${error?.toString()}');

      cleanQueue();

      isExecuting.value = false;
    });
  }

  void cleanQueue() {
    _queue.removeWhere((uc) {
      bool remove = [UseCaseState.done, UseCaseState.error].contains(
        uc.status.state,
      );

      if (remove) {
        logV('Removed ${uc.runtimeType} from the queue');
      }

      return remove;
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
    // Check UseCase exists with matching args. An abandoned UseCase is never a
    // match: the executor gave up on it, so a new request must dispatch a fresh
    // run rather than attach to it or relay its timeout status.
    var idx = _queue.indexWhere((q) => q.isType<T>(args) && !q.abandoned);

    // If not exists, add to queue.
    if (idx == -1 || uc.allowConcurrency) {
      logV('${uc.runtimeType} added to the queue');
      _queue.add(_UseCaseWrapper<T>(uc, args, observer));
    } else if (observer != null) {
      // Otherwise grab the existing UseCase
      var existing = _queue[idx];

      // If the existing UseCase is done executing, just relay the status.
      if ([UseCaseState.done, UseCaseState.error]
          .contains(existing.status.state)) {
        logV('${uc.runtimeType} used result of already completed UseCase');
        observer.onUseCaseUpdate(existing.status);
        return;
      }

      logV('${uc.runtimeType} added as an observer to an already existing UseCase');

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

  /// Set when the batch this UseCase belonged to exceeded
  /// [UseCaseExecutor.batchTimeout]. The UseCase may still be running, but the
  /// executor has stopped waiting on it and has already notified its observers,
  /// so any result it later produces is discarded.
  bool abandoned = false;

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
