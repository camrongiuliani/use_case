import 'package:use_case/use_case.dart';

/// Thrown when a UseCase does not have the required params to execute.
class UseCaseMissingParameterException implements Exception {
  final UseCase useCase;
  final String? parameter;

  UseCaseMissingParameterException(this.useCase, this.parameter);

  @override
  String toString() {
    return 'UseCaseMissingParameterException: ${useCase.runtimeType} is missing a required parameter ${parameter ?? ''}';
  }
}

/// Thrown when a UseCase does not get a param of the correct type.
class UseCaseInvalidParameterException implements Exception {
  final UseCase useCase;
  final Type was, expected;

  UseCaseInvalidParameterException(this.useCase, this.was, this.expected);

  @override
  String toString() {
    return 'UseCaseInvalidParameterException: ${useCase.runtimeType} expected $expected, was $was';
  }
}
