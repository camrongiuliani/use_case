import 'package:use_case/use_case.dart';

class UseCaseTrigger<T extends UseCase> {}

class UseCaseRegistry {
  UseCaseRegistry();

  final Map<Type, UseCaseBuilder> _useCases = {};

  bool exists<T extends UseCase>() => _useCases.containsKey(T);

  T buildUseCase<T extends UseCase>() {
    assert(exists<T>(), 'UseCase ($T) not registered');
    return _useCases[T]!() as T;
  }

  register<T extends UseCase>(UseCaseBuilder<T> builder) {
    assert(!exists<T>(), 'UseCase ($T) was already registered.');
    _useCases[T] = builder;
  }

  Future<void> flush() async {
    _useCases.clear();
  }
}
