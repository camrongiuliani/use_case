// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'use_case_status.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

/// @nodoc
mixin _$UseCaseStatus<T> {
  Type get type => throw _privateConstructorUsedError;
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
      _$UseCaseStatusCopyWithImpl<T, $Res, UseCaseStatus<T>>;
  @useResult
  $Res call(
      {Type type,
      UseCaseState state,
      T? data,
      Object? error,
      StackTrace? stackTrace});
}

/// @nodoc
class _$UseCaseStatusCopyWithImpl<T, $Res, $Val extends UseCaseStatus<T>>
    implements $UseCaseStatusCopyWith<T, $Res> {
  _$UseCaseStatusCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? state = null,
    Object? data = freezed,
    Object? error = freezed,
    Object? stackTrace = freezed,
  }) {
    return _then(_value.copyWith(
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as Type,
      state: null == state
          ? _value.state
          : state // ignore: cast_nullable_to_non_nullable
              as UseCaseState,
      data: freezed == data
          ? _value.data
          : data // ignore: cast_nullable_to_non_nullable
              as T?,
      error: freezed == error ? _value.error : error,
      stackTrace: freezed == stackTrace
          ? _value.stackTrace
          : stackTrace // ignore: cast_nullable_to_non_nullable
              as StackTrace?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$UseCaseStatusImplCopyWith<T, $Res>
    implements $UseCaseStatusCopyWith<T, $Res> {
  factory _$$UseCaseStatusImplCopyWith(_$UseCaseStatusImpl<T> value,
          $Res Function(_$UseCaseStatusImpl<T>) then) =
      __$$UseCaseStatusImplCopyWithImpl<T, $Res>;
  @override
  @useResult
  $Res call(
      {Type type,
      UseCaseState state,
      T? data,
      Object? error,
      StackTrace? stackTrace});
}

/// @nodoc
class __$$UseCaseStatusImplCopyWithImpl<T, $Res>
    extends _$UseCaseStatusCopyWithImpl<T, $Res, _$UseCaseStatusImpl<T>>
    implements _$$UseCaseStatusImplCopyWith<T, $Res> {
  __$$UseCaseStatusImplCopyWithImpl(_$UseCaseStatusImpl<T> _value,
      $Res Function(_$UseCaseStatusImpl<T>) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? state = null,
    Object? data = freezed,
    Object? error = freezed,
    Object? stackTrace = freezed,
  }) {
    return _then(_$UseCaseStatusImpl<T>(
      null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as Type,
      state: null == state
          ? _value.state
          : state // ignore: cast_nullable_to_non_nullable
              as UseCaseState,
      data: freezed == data
          ? _value.data
          : data // ignore: cast_nullable_to_non_nullable
              as T?,
      error: freezed == error ? _value.error : error,
      stackTrace: freezed == stackTrace
          ? _value.stackTrace
          : stackTrace // ignore: cast_nullable_to_non_nullable
              as StackTrace?,
    ));
  }
}

/// @nodoc

class _$UseCaseStatusImpl<T> implements _UseCaseStatus<T> {
  const _$UseCaseStatusImpl(this.type,
      {this.state = UseCaseState.none, this.data, this.error, this.stackTrace});

  @override
  final Type type;
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
    return 'UseCaseStatus<$T>(type: $type, state: $state, data: $data, error: $error, stackTrace: $stackTrace)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UseCaseStatusImpl<T> &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.state, state) || other.state == state) &&
            const DeepCollectionEquality().equals(other.data, data) &&
            const DeepCollectionEquality().equals(other.error, error) &&
            (identical(other.stackTrace, stackTrace) ||
                other.stackTrace == stackTrace));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      type,
      state,
      const DeepCollectionEquality().hash(data),
      const DeepCollectionEquality().hash(error),
      stackTrace);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$UseCaseStatusImplCopyWith<T, _$UseCaseStatusImpl<T>> get copyWith =>
      __$$UseCaseStatusImplCopyWithImpl<T, _$UseCaseStatusImpl<T>>(
          this, _$identity);
}

abstract class _UseCaseStatus<T> implements UseCaseStatus<T> {
  const factory _UseCaseStatus(final Type type,
      {final UseCaseState state,
      final T? data,
      final Object? error,
      final StackTrace? stackTrace}) = _$UseCaseStatusImpl<T>;

  @override
  Type get type;
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
  _$$UseCaseStatusImplCopyWith<T, _$UseCaseStatusImpl<T>> get copyWith =>
      throw _privateConstructorUsedError;
}
