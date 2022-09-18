import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:synchronized/synchronized.dart';
import 'package:use_case/use_case.dart';

class UseCaseExecutor {

  final List<_UseCaseWrapper> _queue = [];
  final Lock _executionLock;
  final Lock _notificationLock;

  static UseCaseExecutor? instance;

  UseCaseExecutor._( this._notificationLock, this._executionLock );

  factory UseCaseExecutor() {
    return instance ??= UseCaseExecutor._( Lock(reentrant: true), Lock(reentrant: true) );
  }

  void _notifyObservers( UseCaseStatus status, List<UseCaseObserver> observers ) {
    _notificationLock.synchronized(() {
      for ( var observer in observers ) {
        observer.onUseCaseUpdate( status );
      }
    });
  }

  Future<void> _runQueue() async {

    if ( _queue.isEmpty ) {
      return;
    }

    return _executionLock.synchronized( () {

      // print('UseCase Queue Length: ${_queue.length}');

      List<Completer<void>> completion = [];

      for ( var entry in _queue ) {

        Completer<void> completer = Completer();

        completion.add( completer );

        var useCase = entry.useCase;
        var args = entry.args;
        var observers = entry.observers;

        entry.status = entry.status.copyWith( state: UseCaseState.started );
        _notifyObservers( entry.status, observers );

        Future.sync( () => useCase.execute( args ) ).then( ( val ) {

          entry.status = entry.status.copyWith( state: UseCaseState.done, data: val );
          _notifyObservers( entry.status, observers );

          completer.complete();

        }).onError((error, stackTrace) {

          entry.status = entry.status.copyWith( state: UseCaseState.error, error: error, stackTrace: stackTrace );
          _notifyObservers( entry.status, observers );

          completer.complete();
        });

        entry.status = entry.status.copyWith( state: UseCaseState.waiting );
        _notifyObservers( entry.status, observers );

      }

      return Future.wait( completion.map((e) => e.future) );

    }).then( ( v ) {
      _queue.removeWhere( ( uc ) => [ UseCaseState.done, UseCaseState.error ].contains( uc.status.state ) );

      // print('UseCase Queue Length: ${_queue.length}');

    }).onError((error, stackTrace)  {
      if (kDebugMode) {
        print(error);
      }
    });
  }

  void add( UseCase<dynamic> uc, UseCaseObserver observer, [ Map<String, dynamic>? args ] ) {
    // Check UseCase exists with matching args.
    var idx = _queue.indexWhere( ( q ) => q.id == uc.id && q.args == args );

    // If not exists, add to queue.
    if ( idx == -1 ) {
      _queue.add( _UseCaseWrapper( uc, args, observer ) );
    } else {
      // Otherwise grab the existing UseCase
      var existing = _queue[ idx ];

      // If the existing UseCase is done executing, just relay the status.
      if ( [ UseCaseState.done, UseCaseState.error ].contains( existing.status.state ) ) {
        observer.onUseCaseUpdate( existing.status );
        return;
      }

      // Otherwise, attach this observer to the existing UseCase
      existing.observers.add( observer );

      // observer.onUseCaseUpdate( existing.status );
    }

    if ( ! _executionLock.locked ) {
      _runQueue();
    }
  }
}

class _UseCaseWrapper<T> {
  final String id;
  final UseCase<T> useCase;
  final Map<String, dynamic>? args;
  late UseCaseStatus<T> status;

  final List<UseCaseObserver> observers = [];

  _UseCaseWrapper( this.useCase, this.args, UseCaseObserver observer ) : id = useCase.id {
    observers.add( observer );
    status = UseCaseStatus( id, state: UseCaseState.queued );
    observer.onUseCaseUpdate( status );
  }

}