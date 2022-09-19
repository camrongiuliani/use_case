import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:synchronized/synchronized.dart';
import 'package:use_case/src/use_case_subscription.dart';
import 'package:use_case/use_case.dart';
import 'package:collection/collection.dart';

class UseCaseExecutor {

  final List<_UseCaseWrapper> _queue = [];
  final Map<String, List<UseCaseSubscription>> _subscriptions = {};
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

        if ( _subscriptions.containsKey( useCase.id ) ) {
          observers.addAll( _subscriptions[ useCase.id ]!.map((e) => e.observer) );
        }

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

  UseCaseSubscription subscribe( UseCase<dynamic> uc, UseCaseObserver observer ) {
    var sub = UseCaseSubscription( uc.id, observer, this);

    ( _subscriptions[uc.id] ??= [] ).add( sub );

    return sub;
  }

  void unsubscribe( UseCaseSubscription sub ) {
    _subscriptions[ sub.id ]?.remove( sub );
  }

  bool hasSubscription( UseCaseSubscription sub ) {
    return _subscriptions.containsKey( sub.id ) && _subscriptions[sub.id]!.contains( sub );
  }

  void broadcast( UseCase<dynamic> uc, [ Map<String, dynamic>? args ] ) {
    assert( () {
      return _subscriptions.keys.contains( uc.id ) && _subscriptions[uc.id]!.isNotEmpty;
    }(), 'Requested broadcast for UseCase ${uc.id}, which had no subscriptions' );

    _subscriptions[ uc.id ]!.map((e) => add( uc, UseCaseHandler(onUpdate: (_) {}), args ) );

  }

  void add( UseCase<dynamic> uc, UseCaseObserver? observer, [ Map<String, dynamic>? args ] ) {

    Function mapEq = const MapEquality().equals;

    // Check UseCase exists with matching args.
    var idx = _queue.indexWhere( ( q ) => q.id == uc.id && mapEq( q.args, args ) );

    // If not exists, add to queue.
    if ( idx == -1 ) {
      _queue.add( _UseCaseWrapper( uc, args, observer ) );
    } else if ( observer != null ) {
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

  _UseCaseWrapper( this.useCase, this.args, UseCaseObserver? observer ) : id = useCase.id {
    status = UseCaseStatus( id, state: UseCaseState.queued );

    if ( observer != null ) {
      observers.add( observer );
      observer.onUseCaseUpdate( status );
    }
  }

}