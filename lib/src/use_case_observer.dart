import 'package:use_case/use_case.dart';

abstract class UseCaseObserver {
  void onUseCaseUpdate(UseCaseStatus update) {}
}
