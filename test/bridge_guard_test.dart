import 'dart:async';

import 'package:test/test.dart';
import 'package:use_case/use_case.dart';

/// Holds the execution lock so the two UseCases added behind it land in a
/// single later batch rather than one batch each.
class BlockerUseCase extends UseCase<Object?, String> {
  @override
  FutureOr<String> execute(Object? args) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return 'blocker';
  }
}

class FastUseCase extends UseCase<Object?, String> {
  @override
  FutureOr<String> execute(Object? args) async {
    await Future.delayed(const Duration(milliseconds: 20));
    return 'fast';
  }
}

/// Outlives [FastUseCase] by enough that the batch is still open - and the
/// finished fast entry still in the queue - when flush() runs.
class SlowUseCase extends UseCase<Object?, String> {
  @override
  FutureOr<String> execute(Object? args) async {
    await Future.delayed(const Duration(milliseconds: 600));
    return 'slow';
  }
}

/// Drives one UseCase to a terminal `done` and then flushes while its batch is
/// still open, which notifies a second terminal status - `error` - to the same
/// observer.
///
/// cleanQueue() only runs once the whole batch settles, so between the fast
/// UseCase completing and its slower batch-mate finishing, the fast entry sits
/// in the queue carrying a terminal status. flush() does not check for that,
/// so it notifies over the top.
Future<void> _doubleTerminal(
  UseCaseManager manager,
  void Function() subscribe,
) async {
  manager.register<BlockerUseCase>(BlockerUseCase.new);
  manager.register<FastUseCase>(FastUseCase.new);
  manager.register<SlowUseCase>(SlowUseCase.new);

  manager.call<BlockerUseCase>();

  // Queued while the blocker holds the lock, so both are dispatched together
  // in the batch that follows it.
  await Future.delayed(const Duration(milliseconds: 50));

  subscribe();
  manager.call<SlowUseCase>();

  // Blocker finishes ~400ms, fast ~420ms, slow ~1000ms. At 550ms the fast
  // entry is done but still queued.
  await Future.delayed(const Duration(milliseconds: 500));

  await manager.flush();

  await Future.delayed(const Duration(milliseconds: 200));
}

void main() {
  setUp(() => UseCaseExecutor.instance = null);
  tearDown(() => UseCaseExecutor.instance = null);

  test('callFuture ignores a second terminal status', () async {
    final uncaught = <Object>[];

    Object? value;
    Object? thrown;

    // No expect() inside the zone: a failed matcher would be captured as an
    // uncaught error instead of failing the test.
    await runZonedGuarded(() async {
      final manager = UseCaseManager();

      await _doubleTerminal(manager, () {
        manager.callFuture<FastUseCase>().then<void>(
              (v) => value = v,
              onError: (Object e) => thrown = e,
            );
      });
    }, (error, stack) => uncaught.add(error));

    // The first terminal status wins; the trailing error is absorbed.
    expect(value, 'fast');
    expect(thrown, isNull);
    expect(uncaught, isEmpty);
  });

  test('callStream ignores a second terminal status', () async {
    final uncaught = <Object>[];
    final events = <Object?>[];
    final errors = <Object>[];

    var closed = false;

    await runZonedGuarded(() async {
      final manager = UseCaseManager();

      await _doubleTerminal(manager, () {
        manager.callStream<FastUseCase>().listen(
              events.add,
              onError: errors.add,
              onDone: () => closed = true,
            );
      });
    }, (error, stack) => uncaught.add(error));

    expect(events, ['fast']);
    expect(errors, isEmpty);
    expect(closed, isTrue);
    expect(uncaught, isEmpty);
  });
}
