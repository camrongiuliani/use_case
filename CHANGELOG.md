## 0.0.1

* Initial Release (Beta)

## 0.0.1+1

* Expose Flush

## 0.0.1+2

* Expose UseCaseSubscription

# 0.0.1+3

* Allow covariant dynamic args

# 0.0.1+4

* Bug Fixes

# 0.0.1+5

* Print more verbose to console on error

# 0.0.1+6

* No longer print on error, up to user to print as desired

# 0.0.1+7

* Added debug flag for logging

# 0.0.1+9

* Added use case dispose method

# 0.0.1+10

* Added invoke method

# 0.1.0

* Added invoke method

# 0.1.1

* Expose `isExecuting` getter (bool)

# 0.1.2

* Allow concurrent UseCase executions

# 1.0.0

* Switch from string ID to generics 

# 1.1.1

* Specify GIVEN and RESULT in type args of the UseCase

# 1.1.4

* Allow void RESULT and improve type checking

# 1.1.7

* Remove Flutter dependency

# 1.1.8

* Add timeout on execution lock

# 1.1.9

* Made isExecuting observable, cleanup code

# 1.1.10

* Using BehaviorSubject in DartChangeNotifier

# 1.1.11

* Fix deps

# 1.1.12

* Fixed issues, added more error logs 

# Unreleased

* `UseCaseExecutor` batch timeout is now configurable via the `batchTimeout`
  parameter. Defaults to 60 seconds, so existing behaviour is unchanged.
  Note that `UseCaseExecutor` is a singleton, so the value only applies on the
  first construction.
* The batch timeout now releases the execution lock and resumes draining the
  queue. Previously the timeout was chained onto the future returned by
  `synchronized(...)`, which left the lock held by the abandoned batch and
  skipped the re-drain, so UseCases dispatched after a timeout stayed queued
  until some later unrelated dispatch.
* A timed out UseCase now reaches a terminal state. Its observers are notified
  with `UseCaseState.error` carrying a `UseCaseTimeoutException` (which exposes
  the UseCase type and the timeout that elapsed), instead of being left on
  `UseCaseState.waiting` with no further notification. `UseCaseManager.callFuture`
  and `callStream` therefore surface a timeout as a thrown/emitted
  `UseCaseTimeoutException` rather than never completing.
  BEHAVIOUR CHANGE: consumers that previously saw nothing on a timeout now
  receive an error. `UseCaseState` gained no new value, so existing `switch`
  statements are unaffected.
* The UseCase abandoned by a timeout cannot be cancelled and keeps running, but
  its late result is now discarded: it does not overwrite the timeout status and
  does not notify observers a second time.
* Fixed an error-path double notification. `Future.sync(...).onError(h).then(cb)`
  ran `cb` on the error path as well, because `onError` returns a future that
  completes normally with the handler's `void` return. An erroring UseCase was
  therefore notified `error` and then immediately `done` with `data: null`.
  This was not cosmetic: `UseCaseManager.callFuture` calls
  `completer.completeError(...)` on `error` and then `completer.complete(...)` on
  the trailing `done`, throwing `StateError: Future already completed`, and
  `callStream` likewise called `sink.add` on an already-closed controller. Both
  are fixed by the single `.then(cb, onError: h)` chain.
  BEHAVIOUR CHANGE: an erroring UseCase no longer emits a trailing
  `UseCaseState.done`.
* `flush()` now marks the UseCases it abandons the same way the batch timeout
  does. It previously set `UseCaseState.error` without flagging them, so the
  still-live execution closures delivered `done` after `error` when the UseCase
  eventually finished — the same `StateError: Future already completed` in
  `UseCaseManager.callFuture`, and the same closed-controller `sink.add` in
  `callStream`, by a second route.
* Re-dispatching a UseCase after its batch timed out now starts a fresh run.
  `add()` no longer matches an abandoned entry, so a repeat request is not
  attached as an observer to the run the executor gave up on, and does not have
  the abandoned run's status relayed to it. Retry semantics: after a timeout the
  next `add()` of the same type and args executes the UseCase again; the
  abandoned run keeps going in the background and its result is dropped. One
  logical request can therefore execute twice; the package has no idempotency
  guard, so a UseCase with side effects must handle that itself. Documented in
  the README's Usage section, which previously claimed without qualification
  that a matching re-add means "The UseCase will not be called twice."
* `UseCaseExecutor` now logs a warning when it is constructed with a
  `batchTimeout` that differs from the live singleton's, instead of dropping the
  value silently. The singleton behaviour itself is unchanged — the first
  construction still wins.
  The factory parameter is now `Duration? batchTimeout` (the `batchTimeout`
  FIELD is unchanged: still non-nullable, still defaulting to 60 seconds) so the
  factory can tell "not passed" from "passed 60s". Omitting it is not a
  configuration attempt and is never warned about; previously any default
  construction after a configured one — including `UseCaseManager()` — was
  warned about for a value it never supplied.
  The warning is delivered to the live instance's logger AND to the logger
  passed to the call when they differ, because the instance doing the logging is
  the one the caller failed to configure and may well have no logger at all.
* Removed `test/use_case_test.dart`. It was entirely commented out and imported
  `flutter_test`, which the package never declared, so it only served to make
  `dart test` exit non-zero.
