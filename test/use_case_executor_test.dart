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
}
