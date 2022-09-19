import 'package:use_case/use_case.dart';

class UseCaseSubscription {

  final String id;
  final UseCaseObserver observer;
  final UseCaseExecutor _exe;

  UseCaseSubscription( this.id, this.observer, this._exe );

  bool get disposed => ! _exe.hasSubscription( this );

  dispose() => _exe.unsubscribe( this );

}