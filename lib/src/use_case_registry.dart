import 'package:use_case/use_case.dart';

class UseCaseRegistry {

  UseCaseRegistry();

  final List<UseCase> _useCases = [];

  List<String> get _registeredUseCases => _useCases.isEmpty ? [] : _useCases.map<String>((e) => e.id).toList();

  bool exists( String id ) => _registeredUseCases.contains( id );

  UseCase getUseCase( String id ) {
    assert( _registeredUseCases.contains( id ), 'UseCase $id not registered' );
    return _useCases.firstWhere( (e) => e.id == id );
  }

  register( UseCase uc ) {
    assert( () {
      if ( exists( uc.id ) ) {
        return false;
      }
      return true;
    }(), 'UseCase ${uc.id} was already registered.');

    _useCases.add( uc );

  }

  Future<void> flush() async {
    _useCases.clear();
  }
}