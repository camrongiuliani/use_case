import 'dart:async';
import 'package:rxdart/rxdart.dart';

/// Not part of public API
class DartChangeNotifier<T> {
  final BehaviorSubject<T> _pub;

  /// Not part of public API
  DartChangeNotifier() : _pub = BehaviorSubject<T>();

  /// Not part of public API
  void notify( T object ) {
    _pub.sink.add(object);
  }

  /// Not part of public API
  Stream<T> get stream => _pub.stream;

  /// Not part of public API
  Future<void> close() {
    return _pub.close();
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