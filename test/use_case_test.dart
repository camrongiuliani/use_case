import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:use_case/src/exceptions.dart';

import 'package:use_case/use_case.dart';

class AddingUseCase extends UseCase<Map<String, dynamic>?, int> {
  @override
  FutureOr<int> execute(Map<String, dynamic>? args) async {
    args ??= {};

    _validateArgs(args);

    await Future.delayed(const Duration(seconds: 3));

    return args['first'] + args['second'];
  }

  _validateArgs(Map args) {
    if (!args.containsKey('first')) {
      throw UseCaseMissingParameterException(this, 'first');
    }

    if (!args.containsKey('second')) {
      throw UseCaseMissingParameterException(this, 'second');
    }

    if (args['first'] is! int) {
      throw UseCaseInvalidParameterException(
          this, args['first'].runtimeType, int);
    }

    if (args['second'] is! int) {
      throw UseCaseInvalidParameterException(
          this, args['second'].runtimeType, int);
    }
  }
}

void main() {
  group('UseCase Tests', () {
    test('AddingUseCase Baseline Validation', () async {
      AddingUseCase addingUseCase = AddingUseCase();

      Map<String, dynamic> args = {};

      await expectLater(Future.sync(() => addingUseCase.execute(args)),
          throwsA(const TypeMatcher<UseCaseMissingParameterException>()));

      args['first'] = 1;

      await expectLater(Future.sync(() => addingUseCase.execute(args)),
          throwsA(const TypeMatcher<UseCaseMissingParameterException>()));

      args['second'] = 2;

      await expectLater(() async {
        return addingUseCase.execute(args);
      }(), completes);

      await expectLater(Future.sync(() => addingUseCase.execute(args)),
          completion(equals(3)));

      args['second'] = '2';

      await expectLater(Future.sync(() => addingUseCase.execute(args)),
          throwsA(const TypeMatcher<UseCaseInvalidParameterException>()));
    });

    test('AddingUseCase added to Manager without duplicate', () {
      AddingUseCase addingUseCase = AddingUseCase();

      UseCaseManager manager = UseCaseManager();

      manager.register(() => addingUseCase);

      expect(
        manager.useCaseExists<AddingUseCase>(),
        isTrue,
      );

      expect(
        () => manager.register<AddingUseCase>(() => addingUseCase),
        throwsAssertionError,
      );

      AddingUseCase addingUseCase2 = AddingUseCase();

      expect(
        () => manager.register<AddingUseCase>(
          () => addingUseCase2,
        ),
        throwsAssertionError,
      );
    });

    test('Expect callFuture errors to bubble up.', () async {
      AddingUseCase addingUseCase = AddingUseCase();

      UseCaseManager manager = UseCaseManager();

      manager.register<AddingUseCase>(() => addingUseCase);

      await expectLater(() {
        return manager.callFuture<AddingUseCase>().onError((error, stackTrace) {
          expect(error, isA<Exception>());
          throw error as Exception;
        });
      }, throwsException);
    });

    test('AddingUseCase added to Manager, call as future', () async {
      AddingUseCase addingUseCase = AddingUseCase();

      UseCaseManager manager = UseCaseManager();

      manager.register<AddingUseCase>(() => addingUseCase);

      await expectLater(
        manager.callFuture<AddingUseCase>(),
        throwsA(
          const TypeMatcher<UseCaseMissingParameterException>(),
        ),
      );

      await expectLater(
        manager.callFuture<AddingUseCase>(
          {'first': 1, 'second': '2'},
        ),
        throwsA(
          const TypeMatcher<UseCaseMissingParameterException>(),
        ),
      );

      await expectLater(
        manager.callFuture<AddingUseCase>(
          {'first': 1, 'second': 3},
        ),
        completion(
          equals(4),
        ),
      );

      var result = await manager.callFuture<AddingUseCase>(
        {'first': 1, 'second': 3},
      );

      expect(result, equals(4));
    });

    test('AddingUseCase added to Manager, call with handler', () async {
      AddingUseCase addingUseCase = AddingUseCase();

      UseCaseManager manager = UseCaseManager();

      manager.register<AddingUseCase>(() => addingUseCase);

      Completer completer = Completer();

      var handler = UseCaseHandler(onUpdate: (status) {
        if (status.state == UseCaseState.done) {
          completer.complete(status.data);
        } else if (status.state == UseCaseState.error) {
          completer.completeError(status, status.stackTrace);
        }
      });

      manager.call<AddingUseCase>(
        observer: handler,
        args: {'first': 1, 'second': 3},
      );

      await expectLater(completer.future, completion(equals(4)));
    });

    test('AddingUseCase added to Manager, call with stream', () async {
      AddingUseCase addingUseCase = AddingUseCase();

      UseCaseManager manager = UseCaseManager();

      manager.register<AddingUseCase>(() => addingUseCase);

      Completer completer = Completer();

      Stream s = manager.callStream<AddingUseCase>(
        {'first': 1, 'second': 3},
      );

      StreamSubscription sub = s.listen((event) {
        completer.complete(event);
      });

      await expectLater(completer.future, completion(equals(4)));

      await sub.cancel();
    });

    test('AddingUseCase added to Manager, subscription test', () async {
      AddingUseCase addingUseCase = AddingUseCase();

      UseCaseManager manager = UseCaseManager();

      manager.register<AddingUseCase>(() => addingUseCase);

      Completer completer = Completer();

      List results = [];

      var handler = UseCaseHandler(
        onUpdate: (status) {
          if (status.state == UseCaseState.done) {
            results.add(status.data);
            if (results.length == 2) {
              completer.complete();
            }
          }
        },
      );

      var subs = manager.subscribe<AddingUseCase>(handler);
      var subs2 = manager.subscribe<AddingUseCase>(handler);

      manager.call<AddingUseCase>(
        args: {'first': 1, 'second': 2},
      );
      manager.call<AddingUseCase>(
        args: {'first': 1, 'second': 2},
      );

      await completer.future
          .timeout(const Duration(seconds: 10))
          .onError((error, stackTrace) {
        print(error);
        return null;
      });

      expect(results.length, equals(2));

      subs.dispose();
      subs2.dispose();

      expect(subs.disposed && subs2.disposed, isTrue);

      manager.call<AddingUseCase>(
        args: {'first': 1, 'second': 2},
      );

      await Future.delayed(const Duration(seconds: 4));

      expect(results.length, equals(2));
    });
  });
}
