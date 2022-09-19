import 'dart:async';
import 'package:use_case/src/use_case_registry.dart';
import 'package:use_case/src/use_case_subscription.dart';
import 'package:use_case/use_case.dart';

class UseCaseManager {

  final UseCaseRegistry _registry;
  final UseCaseExecutor _executor;

  UseCaseManager() :
        _registry = UseCaseRegistry(),
        _executor = UseCaseExecutor();

  /// Registers a UseCase
  registerUseCase( covariant UseCase useCase ) {
    _registry.register( useCase );
  }

  bool useCaseExists( String id ) => _registry.exists( id );

  Future<void> call( String id, { UseCaseObserver? observer, Map<String, dynamic>? args } ) async {
    return _executor.add( _registry.getUseCase( id ), observer, args );
  }

  UseCaseSubscription subscribe( String id, UseCaseObserver observer ) {
    return _executor.subscribe( _registry.getUseCase( id ), observer );
  }

    Future callFuture( String id, [ Map<String, dynamic>? args ] ) {

    Completer completer = Completer();

    UseCaseHandler handler = UseCaseHandler(
        onUpdate: ( status ) {
          if ( status.state == UseCaseState.done ) {
            completer.complete( status.data );
          } else if ( status.state == UseCaseState.error ) {
            completer.completeError( status.error ?? status, status.stackTrace );
          }
        }
    );

    call( id, observer: handler, args: args );

    return completer.future;
  }

  Stream callStream( String id, [ Map<String, dynamic>? args ] ) {

    StreamController sc = StreamController();

    UseCaseHandler handler = UseCaseHandler(
        onUpdate: ( status ) {
          if ( status.state == UseCaseState.done ) {
            sc.sink.add( status.data );
            sc.close();
          } else if ( status.state == UseCaseState.error ) {
            sc.sink.addError( status.error ?? status, status.stackTrace );
            sc.close();
          }
        }
    );

    sc.onListen = () {
      call( id, observer: handler, args: args );
    };

    sc.onCancel = () {
      if ( ! sc.hasListener ) {
        sc.close();
      }
    };

    return sc.stream.asBroadcastStream();
  }

}