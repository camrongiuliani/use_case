import 'dart:async';

import 'package:test/test.dart';
import 'package:use_case/use_case.dart';

const String _timeoutLog = 'Timeout while executing UseCases';

class DelayedUseCase extends UseCase<Object?, String> {
  DelayedUseCase(this.name, this.delay);

  final String name;
  final Duration delay;

  @override
  FutureOr<String> execute(Object? args) async {
    await Future.delayed(delay);
    return name;
  }
}

/// A distinct type, so the executor does not fold it into an already queued
/// [DelayedUseCase] as an extra observer.
class OtherDelayedUseCase extends DelayedUseCase {
  OtherDelayedUseCase(String name, Duration delay) : super(name, delay);
}

class BoomException implements Exception {
  const BoomException();

  @override
  String toString() => 'BoomException';
}

class ThrowingUseCase extends UseCase<Object?, String> {
  ThrowingUseCase(this.delay);

  final Duration delay;

  @override
  FutureOr<String> execute(Object? args) async {
    await Future.delayed(delay);
    throw const BoomException();
  }
}

UseCaseHandler _completeOn(
  Completer<UseCaseStatus> completer,
  UseCaseState state,
) {
  return UseCaseHandler(onUpdate: (status) {
    if (status.state == state && !completer.isCompleted) {
      completer.complete(status);
    }
  });
}

Future<void> _waitFor(
  bool Function() predicate, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final watch = Stopwatch()..start();

  while (!predicate()) {
    if (watch.elapsed > timeout) {
      fail('Condition was not met within $timeout');
    }
    await Future.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  setUp(() => UseCaseExecutor.instance = null);
  tearDown(() => UseCaseExecutor.instance = null);

  group('UseCaseExecutor batch timeout', () {
    test('defaults to 60 seconds', () {
      expect(
        UseCaseExecutor().batchTimeout,
        const Duration(seconds: 60),
      );
    });

    test('is only applied on the first construction', () {
      final first = UseCaseExecutor(
        batchTimeout: const Duration(milliseconds: 150),
      );

      final second = UseCaseExecutor(
        batchTimeout: const Duration(seconds: 5),
      );

      expect(identical(first, second), isTrue);
      expect(second.batchTimeout, const Duration(milliseconds: 150));
    });

    test('default timeout does not trip a short batch', () async {
      final logs = <String>[];
      final executor = UseCaseExecutor(logger: (m, _) => logs.add(m));

      final done = Completer<UseCaseStatus>();

      executor.add(
        DelayedUseCase('fast', const Duration(milliseconds: 50)),
        _completeOn(done, UseCaseState.done),
      );

      final status = await done.future.timeout(const Duration(seconds: 5));

      expect(status.data, 'fast');
      expect(logs, isNot(contains(_timeoutLog)));
    });

    test('a custom timeout is honoured', () async {
      final logs = <String>[];
      final executor = UseCaseExecutor(
        batchTimeout: const Duration(milliseconds: 150),
        logger: (m, _) => logs.add(m),
      );

      final watch = Stopwatch()..start();

      executor.add(
        DelayedUseCase('slow', const Duration(seconds: 2)),
        null,
      );

      await _waitFor(() => logs.contains(_timeoutLog));
      watch.stop();

      expect(watch.elapsed, lessThan(const Duration(seconds: 1)));
    });

    test('the execution lock is released when the batch times out', () async {
      final logs = <String>[];
      final executor = UseCaseExecutor(
        batchTimeout: const Duration(milliseconds: 150),
        logger: (m, _) => logs.add(m),
      );

      executor.add(
        DelayedUseCase('slow', const Duration(seconds: 2)),
        null,
      );

      await _waitFor(() => logs.contains(_timeoutLog));

      // add() only starts the queue while the execution lock is free, so this
      // can only complete if the timeout released the lock. The timed out
      // UseCase is still running at this point.
      final done = Completer<UseCaseStatus>();

      executor.add(
        OtherDelayedUseCase('after', const Duration(milliseconds: 10)),
        _completeOn(done, UseCaseState.done),
      );

      final status = await done.future.timeout(const Duration(seconds: 2));

      expect(status.data, 'after');
    });

    test('a UseCase queued during a timed out batch still runs', () async {
      final logs = <String>[];
      final executor = UseCaseExecutor(
        batchTimeout: const Duration(milliseconds: 300),
        logger: (m, _) => logs.add(m),
      );

      final watch = Stopwatch()..start();

      executor.add(
        DelayedUseCase('slow', const Duration(seconds: 2)),
        null,
      );

      // Queued while the batch still holds the execution lock, so add() does
      // not start it. Only the drain that follows the timeout can.
      await Future.delayed(const Duration(milliseconds: 50));

      final done = Completer<UseCaseStatus>();

      executor.add(
        OtherDelayedUseCase('queued', const Duration(milliseconds: 10)),
        _completeOn(done, UseCaseState.done),
      );

      final status = await done.future.timeout(const Duration(seconds: 3));
      watch.stop();

      expect(status.data, 'queued');
      expect(logs, contains(_timeoutLog));
      // It waited for the timeout rather than being dispatched immediately.
      expect(watch.elapsed, greaterThan(const Duration(milliseconds: 250)));
    });
  });

  group('UseCaseExecutor timeout notification', () {
    test(
        'observers of a timed out UseCase are notified with a terminal error '
        'status', () async {
      final logs = <String>[];
      final executor = UseCaseExecutor(
        batchTimeout: const Duration(milliseconds: 150),
        logger: (m, _) => logs.add(m),
      );

      final terminal = Completer<UseCaseStatus>();

      executor.add(
        DelayedUseCase('slow', const Duration(seconds: 2)),
        _completeOn(terminal, UseCaseState.error),
      );

      await _waitFor(() => logs.contains(_timeoutLog));

      final status = await terminal.future.timeout(
        const Duration(seconds: 1),
        onTimeout: () => fail(
          'Observer received no terminal status after the batch timed out',
        ),
      );

      expect(status.state, UseCaseState.error);
      expect(status.error, isA<UseCaseTimeoutException>());

      final error = status.error as UseCaseTimeoutException;

      expect(error.useCaseType, DelayedUseCase);
      expect(error.timeout, const Duration(milliseconds: 150));
    });

    test(
        'a UseCase that completes after its batch was abandoned does not '
        'notify again', () async {
      final logs = <String>[];
      final executor = UseCaseExecutor(
        batchTimeout: const Duration(milliseconds: 150),
        logger: (m, _) => logs.add(m),
      );

      final statuses = <UseCaseStatus>[];

      executor.add(
        DelayedUseCase('slow', const Duration(milliseconds: 400)),
        UseCaseHandler(onUpdate: statuses.add),
      );

      await _waitFor(
        () => statuses.any((s) => s.state == UseCaseState.error),
      );

      final countAtTimeout = statuses.length;

      // Outlive the UseCase's own 400ms completion, which lands well after the
      // 150ms batch timeout abandoned it.
      await Future.delayed(const Duration(milliseconds: 500));

      expect(statuses, hasLength(countAtTimeout));
      expect(
        statuses.map((s) => s.state),
        isNot(contains(UseCaseState.done)),
      );
    });

    test('a re-dispatch after a timeout is not blocked by a stale queue entry',
        () async {
      final logs = <String>[];
      final executor = UseCaseExecutor(
        batchTimeout: const Duration(milliseconds: 150),
        logger: (m, _) => logs.add(m),
      );

      executor.add(
        DelayedUseCase('slow', const Duration(seconds: 2)),
        null,
      );

      await _waitFor(() => logs.contains(_timeoutLog));

      // Same type AND same args as the abandoned run, so the add() dedupe would
      // have matched it and attached this observer to the run the executor gave
      // up on. Getting 'retry' back proves a fresh execution was dispatched.
      final done = Completer<UseCaseStatus>();

      executor.add(
        DelayedUseCase('retry', const Duration(milliseconds: 10)),
        _completeOn(done, UseCaseState.done),
      );

      final status = await done.future.timeout(const Duration(seconds: 2));

      expect(status.data, 'retry');
    });
  });

  group('UseCaseExecutor error notification', () {
    test('an erroring UseCase notifies error once and never a trailing done',
        () async {
      final executor = UseCaseExecutor();

      final statuses = <UseCaseStatus>[];

      executor.add(
        ThrowingUseCase(const Duration(milliseconds: 20)),
        UseCaseHandler(onUpdate: statuses.add),
      );

      await _waitFor(
        () => statuses.any((s) => s.state == UseCaseState.error),
      );

      // Give the old .onError(...).then(...) chain time to fire its spurious
      // done, if it still could.
      await Future.delayed(const Duration(milliseconds: 200));

      expect(
        statuses.where((s) => s.state == UseCaseState.error),
        hasLength(1),
      );
      expect(
        statuses.map((s) => s.state),
        isNot(contains(UseCaseState.done)),
      );
      expect(statuses.last.error, isA<BoomException>());
    });
  });

  group('UseCaseExecutor timeout re-dispatch', () {
    test(
        'a synchronous re-dispatch from the timeout error callback starts a '
        'fresh run', () async {
      final logs = <String>[];
      final executor = UseCaseExecutor(
        batchTimeout: const Duration(milliseconds: 150),
        logger: (m, _) => logs.add(m),
      );

      final retried = Completer<UseCaseStatus>();

      var redispatched = false;

      // onTimeout notifies observers synchronously, BEFORE the .then that runs
      // cleanQueue(). Retrying from inside that notification - the ordinary
      // 'retry in my error callback' pattern - is the window where the
      // abandoned entry is still in the queue, now carrying a terminal status.
      // Without the !abandoned guard, add() matches it and relays the stale
      // timeout status instead of executing anything.
      final handler = UseCaseHandler(onUpdate: (status) {
        if (redispatched ||
            status.state != UseCaseState.error ||
            status.error is! UseCaseTimeoutException) {
          return;
        }

        redispatched = true;

        executor.add(
          DelayedUseCase('retry', const Duration(milliseconds: 10)),
          _completeOn(retried, UseCaseState.done),
        );
      });

      executor.add(
        DelayedUseCase('slow', const Duration(seconds: 2)),
        handler,
      );

      await _waitFor(() => logs.contains(_timeoutLog));

      expect(redispatched, isTrue);

      final status = await retried.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () => fail('re-dispatch never produced a done'),
      );

      expect(status.data, 'retry');
    });
  });

  group('UseCaseManager error bridging', () {
    test(
        'callFuture on a throwing UseCase completes with the error once and '
        'raises no StateError', () async {
      final uncaught = <Object>[];

      Object? thrown;

      // No expect() inside the zone: a failed matcher would be captured as an
      // uncaught error instead of failing the test. Observations are collected
      // here and asserted outside.
      await runZonedGuarded(() async {
        final manager = UseCaseManager();

        manager.register<ThrowingUseCase>(
          () => ThrowingUseCase(const Duration(milliseconds: 20)),
        );

        try {
          await manager.callFuture<ThrowingUseCase>();
        } catch (e) {
          thrown = e;
        }

        // Outlive the trailing `done` the pre-fix chain delivered, which is
        // what called complete() on the already-completed Completer.
        await Future.delayed(const Duration(milliseconds: 200));
      }, (error, stack) => uncaught.add(error));

      expect(thrown, isA<BoomException>());
      expect(uncaught, isEmpty);
    });

    test(
        'callStream on a throwing UseCase emits the error, closes, and raises '
        'no StateError', () async {
      final uncaught = <Object>[];
      final events = <Object?>[];
      final errors = <Object>[];

      var closed = false;

      await runZonedGuarded(() async {
        final manager = UseCaseManager();

        manager.register<ThrowingUseCase>(
          () => ThrowingUseCase(const Duration(milliseconds: 20)),
        );

        final finished = Completer<void>();

        manager.callStream<ThrowingUseCase>().listen(
          events.add,
          onError: errors.add,
          onDone: () {
            closed = true;
            if (!finished.isCompleted) {
              finished.complete();
            }
          },
        );

        await finished.future.timeout(const Duration(seconds: 5));

        // Outlive the trailing `done`, which is what called sink.add() on the
        // already-closed controller.
        await Future.delayed(const Duration(milliseconds: 200));
      }, (error, stack) => uncaught.add(error));

      expect(errors, hasLength(1));
      expect(errors.single, isA<BoomException>());
      expect(events, isEmpty);
      expect(closed, isTrue);
      expect(uncaught, isEmpty);
    });
  });

  group('UseCaseManager flush', () {
    test(
        'flush while a UseCase is running completes callFuture once and '
        'raises no StateError', () async {
      final uncaught = <Object>[];

      Object? thrown;
      var completedNormally = false;

      await runZonedGuarded(() async {
        final manager = UseCaseManager();

        manager.register<DelayedUseCase>(
          () => DelayedUseCase('slow', const Duration(milliseconds: 200)),
        );

        // Attach the handlers synchronously. A Completer completed with an
        // error and no listener yet is reported as unhandled at the end of that
        // microtask turn, which would show up here as a failure that has
        // nothing to do with flush().
        final settled = manager.callFuture<DelayedUseCase>().then<void>(
          (_) {
            completedNormally = true;
          },
          onError: (Object e) {
            thrown = e;
          },
        );

        // Let it start, then abandon it mid-flight.
        await Future.delayed(const Duration(milliseconds: 50));

        await manager.flush();
        await settled;

        // Outlive the UseCase's own 200ms completion, which is when the
        // pre-fix success arm re-completed the already-completed Completer.
        await Future.delayed(const Duration(milliseconds: 400));
      }, (error, stack) => uncaught.add(error));

      expect(completedNormally, isFalse);
      expect(thrown, isA<UseCaseStatus>());
      expect((thrown as UseCaseStatus).state, UseCaseState.error);
      expect(uncaught, isEmpty);
    });
  });

  group('UseCaseExecutor construction diagnostics', () {
    test('a second construction with a different batchTimeout logs a warning',
        () {
      final logs = <String>[];

      final first = UseCaseExecutor(
        batchTimeout: const Duration(milliseconds: 150),
        logger: (m, _) => logs.add(m),
      );

      final second = UseCaseExecutor(
        batchTimeout: const Duration(seconds: 5),
      );

      expect(identical(first, second), isTrue);
      expect(second.batchTimeout, const Duration(milliseconds: 150));
      expect(logs.where((l) => l.contains('was IGNORED')), hasLength(1));

      // Passing the value the instance already has is not a mistake, so it is
      // not warned about.
      UseCaseExecutor(batchTimeout: const Duration(milliseconds: 150));

      expect(logs.where((l) => l.contains('was IGNORED')), hasLength(1));
    });

    test('the warning reaches the caller when the live instance has no logger',
        () {
      // A first construction with no logger at all, which is exactly what
      // UseCaseManager does. Logging only on the live instance would send the
      // warning nowhere.
      final first = UseCaseExecutor(
        batchTimeout: const Duration(milliseconds: 150),
      );

      final logs = <String>[];

      final second = UseCaseExecutor(
        batchTimeout: const Duration(seconds: 5),
        logger: (m, _) => logs.add(m),
      );

      expect(identical(first, second), isTrue);
      expect(second.batchTimeout, const Duration(milliseconds: 150));
      expect(logs.where((l) => l.contains('was IGNORED')), hasLength(1));
    });

    test('omitting batchTimeout is never warned about', () {
      final logs = <String>[];

      UseCaseExecutor(
        batchTimeout: const Duration(milliseconds: 150),
        logger: (m, _) => logs.add(m),
      );

      // UseCaseManager() constructs UseCaseExecutor(debug: debug) with no
      // batchTimeout. That is not a configuration attempt and must not be
      // blamed for the default it never supplied.
      UseCaseManager();

      expect(logs.where((l) => l.contains('was IGNORED')), isEmpty);
    });
  });
}
