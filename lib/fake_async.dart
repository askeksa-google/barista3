// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

int _currentTime = 0;

SplayTreeMap<int, Queue<Timer>> _pending = SplayTreeMap<int, Queue<Timer>>();

abstract class Timer {
  int _time;
  bool isActive = true;

  Timer._(int milliseconds) : _time = _currentTime + milliseconds {
    _insert();
  }

  void _insert() {
    Queue<Timer> queue = _pending.putIfAbsent(_time, () => Queue<Timer>());
    queue.addLast(this);
  }

  void _call();

  factory Timer(Duration duration, void Function() callback) =>
      _OneShotTimer(duration.inMilliseconds, callback);

  factory Timer.periodic(Duration duration, void Function(Timer) callback) =>
      _PeriodicTimer(duration.inMilliseconds, callback);

  static void run(void Function() callback) => Timer(Duration.zero, callback);

  void cancel() => isActive = false;
}

class _OneShotTimer extends Timer {
  final void Function() _callback;

  _OneShotTimer(int milliseconds, this._callback) : super._(milliseconds);

  void _call() => _callback();
}

class _PeriodicTimer extends Timer {
  final void Function(Timer) _callback;
  final int _period;

  _PeriodicTimer(int milliseconds, this._callback)
      : _period = milliseconds,
        super._(milliseconds);

  void _call() {
    _callback(this);
    _time += _period;
    _insert();
  }
}

class _Microtask extends _OneShotTimer {
  _Microtask(void Function() callback) : super(0, callback);

  void _insert() {
    Queue<Timer> queue = _pending.putIfAbsent(_time, () => Queue<Timer>());
    queue.addFirst(this);
  }
}

void scheduleMicrotask(void Function() callback) {
  _Microtask(callback);
}

R runZoned<R>(R body()) {
  return body();
}

R? runZonedGuarded<R>(R body(), void onError(Object error, StackTrace stack)) {
  return body();
}

void fakeAsyncEventLoop() {
  while (_pending.isNotEmpty) {
    _currentTime = _pending.firstKey()!;
    Queue queue = _pending[_currentTime]!;
    while (queue.isNotEmpty) {
      Timer event = queue.removeFirst();
      if (event.isActive) {
        event._call();
      }
    }
    _pending.remove(_currentTime);
  }
}
