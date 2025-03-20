import 'dart:async';

/// Not part of public API
class DartChangeNotifier<T> {
  final StreamController<T> _streamController;

  /// Not part of public API
  DartChangeNotifier() : _streamController = StreamController<T>.broadcast();

  /// Not part of public API
  void notify( T object ) {
    _streamController.add( object );
  }

  /// Not part of public API
  Stream<T> watch() => _streamController.stream;

  /// Not part of public API
  Future<void> close() {
    return _streamController.close();
  }
}

class DartValueNotifier<T> extends DartChangeNotifier<T> {
  T _value;

  DartValueNotifier(this._value);

  T get value => _value;

  set value(T newValue) {
    if (_value != newValue) {
      _value = newValue;
      notify(_value);
    }
  }
}