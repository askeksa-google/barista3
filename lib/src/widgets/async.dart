// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Widgets that handle interaction with asynchronous computations.
///
/// Asynchronous computations are represented by [Future]s and [Stream]s.

import 'package:flute/foundation.dart';

import 'framework.dart';

/// The state of connection to an asynchronous computation.
///
/// The usual flow of state is as follows:
///
/// 1. [none], maybe with some initial data.
/// 2. [waiting], indicating that the asynchronous operation has begun,
///    typically with the data being null.
/// 3. [active], with data being non-null, and possible changing over time.
/// 4. [done], with data being non-null.
///
/// See also:
///
///  * [AsyncSnapshot], which augments a connection state with information
///    received from the asynchronous computation.
enum ConnectionState {
  /// Not currently connected to any asynchronous computation.
  ///
  /// For example, a [FutureBuilder] whose [FutureBuilder.future] is null.
  none,

  /// Connected to an asynchronous computation and awaiting interaction.
  waiting,

  /// Connected to an active asynchronous computation.
  ///
  /// For example, a [Stream] that has returned at least one value, but is not
  /// yet done.
  active,

  /// Connected to a terminated asynchronous computation.
  done,
}

/// Immutable representation of the most recent interaction with an asynchronous
/// computation.
///
/// See also:
///
///  * [StreamBuilder], which builds itself based on a snapshot from interacting
///    with a [Stream].
///  * [FutureBuilder], which builds itself based on a snapshot from interacting
///    with a [Future].
@immutable
class AsyncSnapshot<T> {
  /// Creates an [AsyncSnapshot] with the specified [connectionState],
  /// and optionally either [data] or [error] with an optional [stackTrace]
  /// (but not both data and error).
  const AsyncSnapshot._(
      this.connectionState, this.data, this.error, this.stackTrace)
      : assert(connectionState != null),
        assert(!(data != null && error != null)),
        assert(stackTrace == null || error != null);

  /// Creates an [AsyncSnapshot] in [ConnectionState.none] with null data and error.
  const AsyncSnapshot.nothing()
      : this._(ConnectionState.none, null, null, null);

  /// Creates an [AsyncSnapshot] in [ConnectionState.waiting] with null data and error.
  const AsyncSnapshot.waiting()
      : this._(ConnectionState.waiting, null, null, null);

  /// Creates an [AsyncSnapshot] in the specified [state] and with the specified [data].
  const AsyncSnapshot.withData(ConnectionState state, T data)
      : this._(state, data, null, null);

  /// Creates an [AsyncSnapshot] in the specified [state] with the specified [error]
  /// and a [stackTrace].
  ///
  /// If no [stackTrace] is explicitly specified, [StackTrace.empty] will be used instead.
  const AsyncSnapshot.withError(
    ConnectionState state,
    Object error, [
    StackTrace stackTrace = StackTrace.empty,
  ]) : this._(state, null, error, stackTrace);

  /// Current state of connection to the asynchronous computation.
  final ConnectionState connectionState;

  /// The latest data received by the asynchronous computation.
  ///
  /// If this is non-null, [hasData] will be true.
  ///
  /// If [error] is not null, this will be null. See [hasError].
  ///
  /// If the asynchronous computation has never returned a value, this may be
  /// set to an initial data value specified by the relevant widget. See
  /// [FutureBuilder.initialData] and [StreamBuilder.initialData].
  final T? data;

  /// Returns latest data received, failing if there is no data.
  ///
  /// Throws [error], if [hasError]. Throws [StateError], if neither [hasData]
  /// nor [hasError].
  T get requireData {
    if (hasData) return data!;
    if (hasError) throw error!;
    throw StateError('Snapshot has neither data nor error');
  }

  /// The latest error object received by the asynchronous computation.
  ///
  /// If this is non-null, [hasError] will be true.
  ///
  /// If [data] is not null, this will be null.
  final Object? error;

  /// The latest stack trace object received by the asynchronous computation.
  ///
  /// This will not be null iff [error] is not null. Consequently, [stackTrace]
  /// will be non-null when [hasError] is true.
  ///
  /// However, even when not null, [stackTrace] might be empty. The stack trace
  /// is empty when there is an error but no stack trace has been provided.
  final StackTrace? stackTrace;

  /// Returns a snapshot like this one, but in the specified [state].
  ///
  /// The [data], [error], and [stackTrace] fields persist unmodified, even if
  /// the new state is [ConnectionState.none].
  AsyncSnapshot<T> inState(ConnectionState state) =>
      AsyncSnapshot<T>._(state, data, error, stackTrace);

  /// Returns whether this snapshot contains a non-null [data] value.
  ///
  /// This can be false even when the asynchronous computation has completed
  /// successfully, if the computation did not return a non-null value. For
  /// example, a [void] will complete with the null value even if it
  /// completes successfully.
  bool get hasData => data != null;

  /// Returns whether this snapshot contains a non-null [error] value.
  ///
  /// This is always true if the asynchronous computation's last result was
  /// failure.
  bool get hasError => error != null;

  @override
  String toString() =>
      '${objectRuntimeType(this, 'AsyncSnapshot')}($connectionState, $data, $error, $stackTrace)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AsyncSnapshot<T> &&
        other.connectionState == connectionState &&
        other.data == data &&
        other.error == error &&
        other.stackTrace == stackTrace;
  }

  @override
  int get hashCode => hashValues(connectionState, data, error);
}

/// Signature for strategies that build widgets based on asynchronous
/// interaction.
///
/// See also:
///
///  * [StreamBuilder], which delegates to an [AsyncWidgetBuilder] to build
///    itself based on a snapshot from interacting with a [Stream].
///  * [FutureBuilder], which delegates to an [AsyncWidgetBuilder] to build
///    itself based on a snapshot from interacting with a [Future].
typedef AsyncWidgetBuilder<T> = Widget Function(
    BuildContext context, AsyncSnapshot<T> snapshot);

/// Widget that builds itself based on the latest snapshot of interaction with
/// a [Future].
///
/// The [future] must have been obtained earlier, e.g. during [State.initState],
/// [State.didUpdateWidget], or [State.didChangeDependencies]. It must not be
/// created during the [State.build] or [StatelessWidget.build] method call when
/// constructing the [FutureBuilder]. If the [future] is created at the same
/// time as the [FutureBuilder], then every time the [FutureBuilder]'s parent is
/// rebuilt, the asynchronous task will be restarted.
///
/// A general guideline is to assume that every `build` method could get called
/// every frame, and to treat omitted calls as an optimization.
///
/// {@youtube 560 315 https://www.youtube.com/watch?v=ek8ZPdWj4Qo}
///
/// ## Timing
///
/// Widget rebuilding is scheduled by the completion of the future, using
/// [State.setState], but is otherwise decoupled from the timing of the future.
/// The [builder] callback is called at the discretion of the Flutter pipeline, and
/// will thus receive a timing-dependent sub-sequence of the snapshots that
/// represent the interaction with the future.
///
/// A side-effect of this is that providing a new but already-completed future
/// to a [FutureBuilder] will result in a single frame in the
/// [ConnectionState.waiting] state. This is because there is no way to
/// synchronously determine that a [Future] has already completed.
///
/// ## Builder contract
///
/// For a future that completes successfully with data, assuming [initialData]
/// is null, the [builder] will be called with either both or only the latter of
/// the following snapshots:
///
/// * `AsyncSnapshot<String>.withData(ConnectionState.waiting, null)`
/// * `AsyncSnapshot<String>.withData(ConnectionState.done, 'some data')`
///
/// If that same future instead completed with an error, the [builder] would be
/// called with either both or only the latter of:
///
/// * `AsyncSnapshot<String>.withData(ConnectionState.waiting, null)`
/// * `AsyncSnapshot<String>.withError(ConnectionState.done, 'some error', someStackTrace)`
///
/// The initial snapshot data can be controlled by specifying [initialData]. You
/// would use this facility to ensure that if the [builder] is invoked before
/// the future completes, the snapshot carries data of your choice rather than
/// the default null value.
///
/// The data and error fields of the snapshot change only as the connection
/// state field transitions from `waiting` to `done`, and they will be retained
/// when changing the [FutureBuilder] configuration to another future. If the
/// old future has already completed successfully with data as above, changing
/// configuration to a new future results in snapshot pairs of the form:
///
/// * `AsyncSnapshot<String>.withData(ConnectionState.none, 'data of first future')`
/// * `AsyncSnapshot<String>.withData(ConnectionState.waiting, 'data of second future')`
///
/// In general, the latter will be produced only when the new future is
/// non-null, and the former only when the old future is non-null.
///
/// A [FutureBuilder] behaves identically to a [StreamBuilder] configured with
/// `future?.asStream()`, except that snapshots with `ConnectionState.active`
/// may appear for the latter, depending on how the stream is implemented.
///
/// {@tool dartpad --template=stateful_widget_material_no_null_safety}
///
/// This sample shows a [FutureBuilder] that displays a loading spinner while it
/// loads data. It displays a success icon and text if the [Future] completes
/// with a result, or an error icon and text if the [Future] completes with an
/// error. Assume the `_calculation` field is set by pressing a button elsewhere
/// in the UI.
///
/// ```dart
/// String _calculation = String.delayed(
///   Duration(seconds: 2),
///   () => 'Data Loaded',
/// );
///
/// Widget build(BuildContext context) {
///   return DefaultTextStyle(
///     style: Theme.of(context).textTheme.headline2,
///     textAlign: TextAlign.center,
///     child: FutureBuilder<String>(
///       future: _calculation, // a previously-obtained String or null
///       builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
///         List<Widget> children;
///         if (snapshot.hasData) {
///           children = <Widget>[
///             Icon(
///               Icons.check_circle_outline,
///               color: Colors.green,
///               size: 60,
///             ),
///             Padding(
///               padding: const EdgeInsets.only(top: 16),
///               child: Text('Result: ${snapshot.data}'),
///             )
///           ];
///         } else if (snapshot.hasError) {
///           children = <Widget>[
///             Icon(
///               Icons.error_outline,
///               color: Colors.red,
///               size: 60,
///             ),
///             Padding(
///               padding: const EdgeInsets.only(top: 16),
///               child: Text('Error: ${snapshot.error}'),
///             )
///           ];
///         } else {
///           children = <Widget>[
///             SizedBox(
///               child: CircularProgressIndicator(),
///               width: 60,
///               height: 60,
///             ),
///             const Padding(
///               padding: EdgeInsets.only(top: 16),
///               child: Text('Awaiting result...'),
///             )
///           ];
///         }
///         return Center(
///           child: Column(
///             mainAxisAlignment: MainAxisAlignment.center,
///             crossAxisAlignment: CrossAxisAlignment.center,
///             children: children,
///           ),
///         );
///       },
///     ),
///   );
/// }
/// ```
/// {@end-tool}
// TODO(ianh): remove unreachable code above once https://github.com/dart-lang/sdk/issues/35520 is fixed
class FutureBuilder<T> extends StatefulWidget {
  /// Creates a widget that builds itself based on the latest snapshot of
  /// interaction with a [Future].
  ///
  /// The [builder] must not be null.
  const FutureBuilder({
    Key? key,
    this.future,
    this.initialData,
    required this.builder,
  })  : assert(builder != null),
        super(key: key);

  /// The asynchronous computation to which this builder is currently connected,
  /// possibly null.
  ///
  /// If no future has yet completed, including in the case where [future] is
  /// null, the data provided to the [builder] will be set to [initialData].
  final T? future;

  /// The build strategy currently used by this builder.
  ///
  /// The builder is provided with an [AsyncSnapshot] object whose
  /// [AsyncSnapshot.connectionState] property will be one of the following
  /// values:
  ///
  ///  * [ConnectionState.none]: [future] is null. The [AsyncSnapshot.data] will
  ///    be set to [initialData], unless a future has previously completed, in
  ///    which case the previous result persists.
  ///
  ///  * [ConnectionState.waiting]: [future] is not null, but has not yet
  ///    completed. The [AsyncSnapshot.data] will be set to [initialData],
  ///    unless a future has previously completed, in which case the previous
  ///    result persists.
  ///
  ///  * [ConnectionState.done]: [future] is not null, and has completed. If the
  ///    future completed successfully, the [AsyncSnapshot.data] will be set to
  ///    the value to which the future completed. If it completed with an error,
  ///    [AsyncSnapshot.hasError] will be true and [AsyncSnapshot.error] will be
  ///    set to the error object.
  ///
  /// This builder must only return a widget and should not have any side
  /// effects as it may be called multiple times.
  final AsyncWidgetBuilder<T> builder;

  /// The data that will be used to create the snapshots provided until a
  /// non-null [future] has completed.
  ///
  /// If the future completes with an error, the data in the [AsyncSnapshot]
  /// provided to the [builder] will become null, regardless of [initialData].
  /// (The error itself will be available in [AsyncSnapshot.error], and
  /// [AsyncSnapshot.hasError] will be true.)
  final T? initialData;

  @override
  State<FutureBuilder<T>> createState() => _FutureBuilderState<T>();
}

/// State for [FutureBuilder].
class _FutureBuilderState<T> extends State<FutureBuilder<T>> {
  /// An object that identifies the currently active callbacks. Used to avoid
  /// calling setState from stale callbacks, e.g. after disposal of this state,
  /// or after widget reconfiguration to a new Future.
  Object? _activeCallbackIdentity;
  late AsyncSnapshot<T> _snapshot;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.initialData == null
        ? AsyncSnapshot<T>.nothing()
        : AsyncSnapshot<T>.withData(
            ConnectionState.none, widget.initialData as T);
    _subscribe();
  }

  @override
  void didUpdateWidget(FutureBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.future != widget.future) {
      if (_activeCallbackIdentity != null) {
        _unsubscribe();
        _snapshot = _snapshot.inState(ConnectionState.none);
      }
      _subscribe();
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _snapshot);

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  void _subscribe() {
    if (widget.future != null) {
      final Object callbackIdentity = Object();
      _activeCallbackIdentity = callbackIdentity;
      var data = widget.future!;
      if (_activeCallbackIdentity == callbackIdentity) {
        setState(() {
          _snapshot = AsyncSnapshot<T>.withData(ConnectionState.done, data);
        });
      }
      _snapshot = _snapshot.inState(ConnectionState.waiting);
    }
  }

  void _unsubscribe() {
    _activeCallbackIdentity = null;
  }
}
