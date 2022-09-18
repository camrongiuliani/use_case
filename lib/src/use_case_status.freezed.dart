// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target

part of 'use_case_status.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

/// @nodoc
mixin _$UseCaseStatus<T> {
  String get id => throw _privateConstructorUsedError;
  UseCaseState get state => throw _privateConstructorUsedError;
  T? get data => throw _privateConstructorUsedError;
  Object? get error => throw _privateConstructorUsedError;
  StackTrace? get stackTrace => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $UseCaseStatusCopyWith<T, UseCaseStatus<T>> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UseCaseStatusCopyWith<T, $Res> {
  factory $UseCaseStatusCopyWith(
          UseCaseStatus<T> value, $Res Function(UseCaseStatus<T>) then) =
      _$UseCaseStatusCopyWithImpl<T, $Res>;
  $Res call(
      {String id,
      UseCaseState state,
      T? data,
      Object? error,
      StackTrace? stackTrace});
}

/// @nodoc
class _$UseCaseStatusCopyWithImpl<T, $Res>
    implements $UseCaseStatusCopyWith<T, $Res> {
  _$UseCaseStatusCopyWithImpl(this._value, this._then);

  final UseCaseStatus<T> _value;
  // ignore: unused_field
  final $Res Function(UseCaseStatus<T>) _then;

  @override
  $Res call({
    Object? id = freezed,
    Object? state = freezed,
    Object? data = freezed,
    Object? error = freezed,
    Object? stackTrace = freezed,
  }) {
    return _then(_value.copyWith(
      id: id == freezed
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      state: state == freezed
          ? _value.state
          : state // ignore: cast_nullable_to_non_nullable
              as UseCaseState,
      data: data == freezed
          ? _value.data
          : data // ignore: cast_nullable_to_non_nullable
              as T?,
      error: error == freezed ? _value.error : error,
      stackTrace: stackTrace == freezed
          ? _value.stackTrace
          : stackTrace // ignore: cast_nullable_to_non_nullable
              as StackTrace?,
    ));
  }
}

/// @nodoc
abstract class _$$_UseCaseStatusCopyWith<T, $Res>
    implements $UseCaseStatusCopyWith<T, $Res> {
  factory _$$_UseCaseStatusCopyWith(
          _$_UseCaseStatus<T> value, $Res Function(_$_UseCaseStatus<T>) then) =
      __$$_UseCaseStatusCopyWithImpl<T, $Res>;
  @override
  $Res call(
      {String id,
      UseCaseState state,
      T? data,
      Object? error,
      StackTrace? stackTrace});
}

/// @nodoc
class __$$_UseCaseStatusCopyWithImpl<T, $Res>
    extends _$UseCaseStatusCopyWithImpl<T, $Res>
    implements _$$_UseCaseStatusCopyWith<T, $Res> {
  __$$_UseCaseStatusCopyWithImpl(
      _$_UseCaseStatus<T> _value, $Res Function(_$_UseCaseStatus<T>) _then)
      : super(_value, (v) => _then(v as _$_UseCaseStatus<T>));

  @override
  _$_UseCaseStatus<T> get _value => super._value as _$_UseCaseStatus<T>;

  @override
  $Res call({
    Object? id = freezed,
    Object? state = freezed,
    Object? data = freezed,
    Object? error = freezed,
    Object? stackTrace = freezed,
  }) {
    return _then(_$_UseCaseStatus<T>(
      id == freezed
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      state: state == freezed
          ? _value.state
          : state // ignore: cast_nullable_to_non_nullable
              as UseCaseState,
      data: data == freezed
          ? _value.data
          : data // ignore: cast_nullable_to_non_nullable
              as T?,
      error: error == freezed ? _value.error : error,
      stackTrace: stackTrace == freezed
          ? _value.stackTrace
          : stackTrace // ignore: cast_nullable_to_non_nullable
              as StackTrace?,
    ));
  }
}

/// @nodoc

class _$_UseCaseStatus<T> implements _UseCaseStatus<T> {
  const _$_UseCaseStatus(this.id,
      {this.state = UseCaseState.none, this.data, this.error, this.stackTrace});

  @override
  final String id;
  @override
  @JsonKey()
  final UseCaseState state;
  @override
  final T? data;
  @override
  final Object? error;
  @override
  final StackTrace? stackTrace;

  @override
  String toString() {
    return 'UseCaseStatus<$T>(id: $id, state: $state, data: $data, error: $error, stackTrace: $stackTrace)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_UseCaseStatus<T> &&
            const DeepCollectionEquality().equals(other.id, id) &&
            const DeepCollectionEquality().equals(other.state, state) &&
            const DeepCollectionEquality().equals(other.data, data) &&
            const DeepCollectionEquality().equals(other.error, error) &&
            const DeepCollectionEquality()
                .equals(other.stackTrace, stackTrace));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(id),
      const DeepCollectionEquality().hash(state),
      const DeepCollectionEquality().hash(data),
      const DeepCollectionEquality().hash(error),
      const DeepCollectionEquality().hash(stackTrace));

  @JsonKey(ignore: true)
  @override
  _$$_UseCaseStatusCopyWith<T, _$_UseCaseStatus<T>> get copyWith =>
      __$$_UseCaseStatusCopyWithImpl<T, _$_UseCaseStatus<T>>(this, _$identity);
}

abstract class _UseCaseStatus<T> implements UseCaseStatus<T> {
  const factory _UseCaseStatus(final String id,
      {final UseCaseState state,
      final T? data,
      final Object? error,
      final StackTrace? stackTrace}) = _$_UseCaseStatus<T>;

  @override
  String get id;
  @override
  UseCaseState get state;
  @override
  T? get data;
  @override
  Object? get error;
  @override
  StackTrace? get stackTrace;
  @override
  @JsonKey(ignore: true)
  _$$_UseCaseStatusCopyWith<T, _$_UseCaseStatus<T>> get copyWith =>
      throw _privateConstructorUsedError;
}
