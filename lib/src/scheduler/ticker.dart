// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flute/foundation.dart';

import 'binding.dart';

/// Signature for the callback passed to the [Ticker] class's constructor.
///
/// The argument is the time that the object had spent enabled so far
/// at the time of the callback being called.
typedef TickerCallback = void Function(Duration elapsed);

/// An interface implemented by classes that can vend [Ticker] objects.
///
/// Tickers can be used by any object that wants to be notified whenever a frame
/// triggers, but are most commonly used indirectly via an
/// [AnimationController]. [AnimationController]s need a [TickerProvider] to
/// obtain their [Ticker]. If you are creating an [AnimationController] from a
/// [State], then you can use the [TickerProviderStateMixin] and
/// [SingleTickerProviderStateMixin] classes to obtain a suitable
/// [TickerProvider]. The widget test framework [WidgetTester] object can be
/// used as a ticker provider in the context of tests. In other contexts, you
/// will have to either pass a [TickerProvider] from a higher level (e.g.
/// indirectly from a [State] that mixes in [TickerProviderStateMixin]), or
/// create a custom [TickerProvider] subclass.
abstract class TickerProvider {
  /// Abstract const constructor. This constructor enables subclasses to provide
  /// const constructors so that they can be used in const expressions.
  const TickerProvider();

  /// Creates a ticker with the given callback.
  ///
  /// The kind of ticker provided depends on the kind of ticker provider.
  @factory
  Ticker createTicker(TickerCallback onTick);
}

// TODO(jacobr): make Ticker use Diagnosticable to simplify reporting errors
// related to a ticker.
/// Calls its callback once per animation frame.
///
/// When created, a ticker is initially disabled. Call [start] to
/// enable the ticker.
///
/// A [Ticker] can be silenced by setting [muted] to true. While silenced, time
/// still elapses, and [start] and [stop] can still be called, but no callbacks
/// are called.
///
/// By convention, the [start] and [stop] methods are used by the ticker's
/// consumer, and the [muted] property is controlled by the [TickerProvider]
/// that created the ticker.
///
/// Tickers are driven by the [SchedulerBinding]. See
/// [SchedulerBinding.scheduleFrameCallback].
class Ticker {
  /// Creates a ticker that will call the provided callback once per frame while
  /// running.
  ///
  /// An optional label can be provided for debugging purposes. That label
  /// will appear in the [toString] output in debug builds.
  Ticker(this._onTick, {this.debugLabel}) {
    assert(() {
      _debugCreationStack = StackTrace.current;
      return true;
    }());
  }

  /// Whether this ticker has been silenced.
  ///
  /// While silenced, a ticker's clock can still run, but the callback will not
  /// be called.
  bool get muted => _muted;
  bool _muted = false;

  /// When set to true, silences the ticker, so that it is no longer ticking. If
  /// a tick is already scheduled, it will unschedule it. This will not
  /// unschedule the next frame, though.
  ///
  /// When set to false, unsilences the ticker, potentially scheduling a frame
  /// to handle the next tick.
  ///
  /// By convention, the [muted] property is controlled by the object that
  /// created the [Ticker] (typically a [TickerProvider]), not the object that
  /// listens to the ticker's ticks.
  set muted(bool value) {
    if (value == muted) return;
    _muted = value;
    if (value) {
      unscheduleTick();
    } else if (shouldScheduleTick) {
      scheduleTick();
    }
  }

  /// Whether this [Ticker] has scheduled a call to call its callback
  /// on the next frame.
  ///
  /// A ticker that is [muted] can be active (see [isActive]) yet not be
  /// ticking. In that case, the ticker will not call its callback, and
  /// [isTicking] will be false, but time will still be progressing.
  ///
  /// This will return false if the [SchedulerBinding.lifecycleState] is one
  /// that indicates the application is not currently visible (e.g. if the
  /// device's screen is turned off).
  bool get isTicking {
    if (muted) return false;
    if (SchedulerBinding.instance!.framesEnabled) return true;
    if (SchedulerBinding.instance!.schedulerPhase != SchedulerPhase.idle)
      return true; // for example, we might be in a warm-up frame or forced frame
    return false;
  }

  /// Whether time is elapsing for this [Ticker]. Becomes true when [start] is
  /// called and false when [stop] is called.
  ///
  /// A ticker can be active yet not be actually ticking (i.e. not be calling
  /// the callback). To determine if a ticker is actually ticking, use
  /// [isTicking].
  bool get isActive => true;

  Duration? _startTime;

  /// Starts the clock for this [Ticker]. If the ticker is not [muted], then this
  /// also starts calling the ticker's callback once per animation frame.
  ///
  /// The returned future resolves once the ticker [stop]s ticking. If the
  /// ticker is disposed, the future does not resolve. A derivative future is
  /// available from the returned [TickerFuture] object that resolves with an
  /// error in that case, via [TickerFuture.orCancel].
  ///
  /// Calling this sets [isActive] to true.
  ///
  /// This method cannot be called while the ticker is active. To restart the
  /// ticker, first [stop] it.
  ///
  /// By convention, this method is used by the object that receives the ticks
  /// (as opposed to the [TickerProvider] which created the ticker).
  void start() {
    assert(() {
      if (isActive) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('A ticker was started twice.'),
          ErrorDescription(
              'A ticker that is already active cannot be started again without first stopping it.'),
          describeForError('The affected ticker was'),
        ]);
      }
      return true;
    }());
    assert(_startTime == null);
    if (shouldScheduleTick) {
      scheduleTick();
    }
    if (SchedulerBinding.instance!.schedulerPhase.index >
            SchedulerPhase.idle.index &&
        SchedulerBinding.instance!.schedulerPhase.index <
            SchedulerPhase.postFrameCallbacks.index)
      _startTime = SchedulerBinding.instance!.currentFrameTimeStamp;
  }

  /// Adds a debug representation of a [Ticker] optimized for including in error
  /// messages.
  DiagnosticsNode describeForError(String name) {
    // TODO(jacobr): make this more structured.
    return DiagnosticsProperty<Ticker>(name, this,
        description: toString2(debugIncludeStack: true));
  }

  /// Stops calling this [Ticker]'s callback.
  ///
  /// If called with the `canceled` argument set to false (the default), causes
  /// the future returned by [start] to resolve. If called with the `canceled`
  /// argument set to true, the future does not resolve, and the future obtained
  /// from [TickerFuture.orCancel], if any, resolves with a [TickerCanceled]
  /// error.
  ///
  /// Calling this sets [isActive] to false.
  ///
  /// This method does nothing if called when the ticker is inactive.
  ///
  /// By convention, this method is used by the object that receives the ticks
  /// (as opposed to the [TickerProvider] which created the ticker).
  void stop({bool canceled = false}) {
    if (!isActive) return;

    // We take the _future into a local variable so that isTicking is false
    // when we actually complete the future (isTicking uses _future to
    // determine its state).
    _startTime = null;

    unscheduleTick();
  }

  final TickerCallback _onTick;

  int? _animationId;

  /// Whether this [Ticker] has already scheduled a frame callback.
  @protected
  bool get scheduled => _animationId != null;

  /// Whether a tick should be scheduled.
  ///
  /// If this is true, then calling [scheduleTick] should succeed.
  ///
  /// Reasons why a tick should not be scheduled include:
  ///
  /// * A tick has already been scheduled for the coming frame.
  /// * The ticker is not active ([start] has not been called).
  /// * The ticker is not ticking, e.g. because it is [muted] (see [isTicking]).
  @protected
  bool get shouldScheduleTick => !muted && isActive && !scheduled;

  void _tick(Duration timeStamp) {
    assert(isTicking);
    assert(scheduled);
    _animationId = null;

    _startTime ??= timeStamp;
    _onTick(timeStamp - _startTime!);

    // The onTick callback may have scheduled another tick already, for
    // example by calling stop then start again.
    if (shouldScheduleTick) scheduleTick(rescheduling: true);
  }

  /// Schedules a tick for the next frame.
  ///
  /// This should only be called if [shouldScheduleTick] is true.
  @protected
  void scheduleTick({bool rescheduling = false}) {
    assert(!scheduled);
    assert(shouldScheduleTick);
    _animationId = SchedulerBinding.instance!
        .scheduleFrameCallback(_tick, rescheduling: rescheduling);
  }

  /// Cancels the frame callback that was requested by [scheduleTick], if any.
  ///
  /// Calling this method when no tick is [scheduled] is harmless.
  ///
  /// This method should not be called when [shouldScheduleTick] would return
  /// true if no tick was scheduled.
  @protected
  void unscheduleTick() {
    if (scheduled) {
      SchedulerBinding.instance!.cancelFrameCallbackWithId(_animationId!);
      _animationId = null;
    }
    assert(!shouldScheduleTick);
  }

  /// Makes this [Ticker] take the state of another ticker, and disposes the
  /// other ticker.
  ///
  /// This is useful if an object with a [Ticker] is given a new
  /// [TickerProvider] but needs to maintain continuity. In particular, this
  /// maintains the identity of the [TickerFuture] returned by the [start]
  /// function of the original [Ticker] if the original ticker is active.
  ///
  /// This ticker must not be active when this method is called.
  void absorbTicker(Ticker originalTicker) {
    assert(_startTime == null);
    assert(_animationId == null);
    _startTime = originalTicker._startTime;
    if (shouldScheduleTick) scheduleTick();
    originalTicker.unscheduleTick();
    originalTicker.dispose();
  }

  /// Release the resources used by this object. The object is no longer usable
  /// after this method is called.
  @mustCallSuper
  void dispose() {
    unscheduleTick();
    assert(() {
      // We intentionally don't null out _startTime. This means that if start()
      // was ever called, the object is now in a bogus state. This weakly helps
      // catch cases of use-after-dispose.
      _startTime = Duration.zero;
      return true;
    }());
  }

  /// An optional label can be provided for debugging purposes.
  ///
  /// This label will appear in the [toString] output in debug builds.
  final String? debugLabel;
  late StackTrace _debugCreationStack;

  @override
  String toString() => toString2();

  String toString2({bool debugIncludeStack = false}) {
    final StringBuffer buffer = StringBuffer();
    buffer.write('${objectRuntimeType(this, 'Ticker')}(');
    assert(() {
      buffer.write(debugLabel ?? '');
      return true;
    }());
    buffer.write(')');
    assert(() {
      if (debugIncludeStack) {
        buffer.writeln();
        buffer.writeln(
            'The stack trace when the $runtimeType was actually created was:');
        FlutterError.defaultStackFilter(
                _debugCreationStack.toString().trimRight().split('\n'))
            .forEach((s) => buffer.writeln(s));
      }
      return true;
    }());
    return buffer.toString();
  }
}
