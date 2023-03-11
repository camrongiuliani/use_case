import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:synchronized/synchronized.dart';
import 'package:use_case/use_case.dart';
import 'package:collection/collection.dart';

class UseCaseExecutor {

  final List<_UseCaseWrapper> _queue = [];
  final Map<String, List<UseCaseSubscription>> _subscriptions = {};
  final Lock _executionLock;
  final Lock _notificationLock;
  final bool debug;

  static UseCaseExecutor? instance;

  UseCaseExecutor._( this._notificationLock, this._executionLock, this.debug );

  factory UseCaseExecutor({bool debug = false}) {
    return instance ??= UseCaseExecutor._( Lock(reentrant: true), Lock(reentrant: true), debug );
  }

  int get queueLength => _queue.length;

  void log(String message) {
    if (kDebugMode && debug) {
      print('UseCaseExecutor: $message');
    }
  }

  void _notifyObservers( UseCaseStatus status, List<UseCaseObserver> observers ) {
    _notificationLock.synchronized(() {
      for ( var observer in observers ) {
        observer.onUseCaseUpdate( status );
      }
    });
  }

  Future<void> flush() async {
    return _executionLock.synchronized(() {
      _queue.clear();
      _subscriptions.clear();
    });
  }

  Future<void> _runQueue() async {

    if ( _queue.isEmpty ) {
      return;
    }

    return _executionLock.synchronized( () async {

      log('Queue Length: ${_queue.length}');

      List<Completer<void>> completion = [];

      for ( var entry in _queue.where((e) => e.status.state == UseCaseState.queued) ) {

        if ( entry.status.state != UseCaseState.queued ) {
          continue;
        }

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

        Future.sync( () async {
          log('${useCase.runtimeType} Starting Execution *****');
          try {
            await useCase.execute( args );
            await useCase.dispose();
          } catch(e) {
            try {
              await useCase.dispose();
            } catch (e) {}

            rethrow;
          }
        }).then( ( val ) {

          entry.status = entry.status.copyWith( state: UseCaseState.done, data: val );

          log('${useCase.runtimeType} Completed Normally');

          _notifyObservers( entry.status, observers );

          completer.complete();
          log('${useCase.runtimeType} Finished Execution*****');

        }).onError((error, stackTrace) {

          entry.status = entry.status.copyWith( state: UseCaseState.error, error: error, stackTrace: stackTrace );

          log('${useCase.runtimeType} Completed With Error');

          _notifyObservers( entry.status, observers );

          completer.complete();
          log('${useCase.runtimeType} Finished Execution*****');
        });

        entry.status = entry.status.copyWith( state: UseCaseState.waiting );
        _notifyObservers( entry.status, observers );

      }

      return await Future.wait( completion.map((e) => e.future) );

    }).then( ( v ) async {
      _queue.removeWhere( ( uc ) {
        bool remove = [ UseCaseState.done, UseCaseState.error ].contains( uc.status.state );

        if (remove) {
          log('Removed ${uc.runtimeType} from the queue');
        }

        return remove;
      });

      if ( _queue.isNotEmpty ) {
        return await _runQueue();
      }

    }).onError((error, stackTrace)  {
      log('Error -> ${error?.toString()}');
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

  void broadcast( UseCase<dynamic> uc, [ dynamic args ] ) {
    assert( () {
      return _subscriptions.keys.contains( uc.id ) && _subscriptions[uc.id]!.isNotEmpty;
    }(), 'Requested broadcast for UseCase ${uc.id}, which had no subscriptions' );

    _subscriptions[ uc.id ]!.map((e) => add( uc, UseCaseHandler(onUpdate: (_) {}), args ) );

  }

  void add( UseCase<dynamic> uc, UseCaseObserver? observer, [ dynamic args ] ) {

    // Check UseCase exists with matching args.
    var idx = _queue.indexWhere( ( q ) => q.id == uc.id  );

    // If not exists, add to queue.
    if ( idx == -1 ) {
      log('${uc.runtimeType} added to the queue');
      _queue.add( _UseCaseWrapper( uc, args, observer ) );
    } else if ( observer != null ) {
      // Otherwise grab the existing UseCase
      var existing = _queue[ idx ];

      // If the existing UseCase is done executing, just relay the status.
      if ( [ UseCaseState.done, UseCaseState.error ].contains( existing.status.state ) ) {
        log('${uc.runtimeType} used result of already completed UseCase');
        observer.onUseCaseUpdate( existing.status );
        return;
      }

      log('${uc.runtimeType} added as an observer to an already existing UseCase');

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
  final dynamic args;
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