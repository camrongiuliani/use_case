## Features

Package that aims to provide the concept of UseCases in an agnostic way.

The purpose is not to fully implement UseCases in accordance with any particular spec (Clean Architect for example); however, it should allow YOU to implement whatever spec you deem necessary. 

## Getting started

Each use case should implement an execute method, with optional arguments.

Arguments must be of type Map<String, dynamic>. This allows this library to be agnostic when it comes to types.

It is possible to add your own (de)serialization should you see fit.

It is recommended to always validate the arguments coming into a UseCase, and throw if the requirements are not met.

Example UseCase Implementation:

```dart
import 'package:use_case/use_case.dart';

class AddingUseCase extends UseCase<int> {

  @override
  String get id => 'AddingUseCase';

  @override
  FutureOr<int> execute(Map<String, dynamic>? args) async {

    args ??= {};

    _validateArgs( args );

    await Future.delayed( const Duration( seconds: 5 ) );

    return args['first'] + args['second'];
  }

  _validateArgs( Map args ) {
    if ( ! args.containsKey('first')  ) {
      throw UseCaseMissingParameterException(this, 'first');
    }

    if ( ! args.containsKey('second') ) {
      throw UseCaseMissingParameterException(this, 'second');
    }

    if ( args['first'] is! int ) {
      throw UseCaseInvalidParameterException(this, args['first'].runtimeType, int);
    }

    if ( args['second'] is! int ) {
      throw UseCaseInvalidParameterException(this, args['second'].runtimeType, int);
    }
  }

}
```

## Usage

As stated above, arguments should be validated in the UseCase. This example would throw a UseCaseMissingParameterException:

```dart
import 'package:use_case/use_case.dart';
import 'adding_use_case.dart';

main() async {
  AddingUseCase addingUseCase = AddingUseCase();

  Map<String, dynamic> args = {};
  
  var myValue = await addingUseCase.execute( args );
}
```

This would complete normally, returning a value of 3:
```dart
import 'package:use_case/use_case.dart';
import 'adding_use_case.dart';

main() async {
  AddingUseCase addingUseCase = AddingUseCase();

  Map<String, dynamic> args = { 'first': 1, 'second': 2 };
  
  var myValue = await addingUseCase.execute( args );
}
```

The above examples show calling a UseCase directly. This is not recommended because it provides no way to abstract the implementation.

The recommended approach is to use the UseCaseManger, which manages UseCases using a String ID. NOTE: The UseCase IDs must be unique.

When using the UseCaseManager, executions are queued and ran asynchronously. 

If a UseCase is added to the queue twice (with matching arguments) during a single queue traversal, the result will be shared between the observers. 

E.g. 
- Class A tells UseCaseManager to execute FetchRecord UseCase, passing in Limit 5.
- Class B tells the UseCaseManager to do the same thing, before the UseCase finishes.
- The manager will attach the Class B observer to the request initiated by class A.
- When the UseCase completes, the manager will push the result to both class A and class B.

The UseCase will not be called twice.

Note: Simple equality is used (==) when comparing arguments. Since the argument type is Map<String, dynamic>, you must ensure that the value type is equatable.

## Additional information

See Examples 
