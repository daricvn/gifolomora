sealed class Result<T, E> {
  const Result();

  bool get isOk => this is Ok<T, E>;
  bool get isErr => this is Err<T, E>;

  T get value;
  E get error;

  R fold<R>({required R Function(T) ok, required R Function(E) err}) =>
      switch (this) {
        Ok(:final value) => ok(value),
        Err(:final error) => err(error),
      };
}

final class Ok<T, E> extends Result<T, E> {
  const Ok(this._value);
  final T _value;

  @override
  T get value => _value;
  @override
  E get error => throw StateError('Ok has no error');
}

final class Err<T, E> extends Result<T, E> {
  const Err(this._error);
  final E _error;

  @override
  T get value => throw StateError('Err has no value');
  @override
  E get error => _error;
}
