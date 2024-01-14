import 'package:use_case/use_case.dart';

typedef OnUpdateCallback = void Function(UseCaseStatus);

class UseCaseHandler implements UseCaseObserver {
  final OnUpdateCallback onUpdate;

  UseCaseHandler({required this.onUpdate});

  @override
  void onUseCaseUpdate(UseCaseStatus event) => onUpdate(event);
}
