// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// TODO(dnfield): remove unused_element ignores when https://github.com/dart-lang/sdk/issues/35164 is resolved.

part of dart.ui;

// Corelib 'print' implementation.
void _print(dynamic arg) {
  _Logger._printString(arg.toString());
}

void _printDebug(dynamic arg) {
  _Logger._printDebugString(arg.toString());
}

class _Logger {
  static void _printString(String? s) {
    throw UnimplementedError();
  }

  static void _printDebugString(String? s) {
    throw UnimplementedError();
  }
}

// If we actually run on big endian machines, we'll need to do something smarter
// here. We don't use [Endian.Host] because it's not a compile-time
// constant and can't propagate into the set/get calls.
const Endian _kFakeHostEndian = Endian.little;

/// Returns runtime Dart compilation trace as a UTF-8 encoded memory buffer.
///
/// The buffer contains a list of symbols compiled by the Dart JIT at runtime up
/// to the point when this function was called. This list can be saved to a text
/// file and passed to tools such as `flutter build` or Dart `gen_snapshot` in
/// order to pre-compile this code offline.
///
/// The list has one symbol per line of the following format:
/// `<namespace>,<class>,<symbol>\n`.
///
/// Here are some examples:
///
/// ```
/// dart:core,Duration,get:inMilliseconds
/// package:flutter/src/widgets/binding.dart,::,runApp
/// file:///.../my_app.dart,::,main
/// ```
///
/// This function is only effective in debug and dynamic modes, and will throw in AOT mode.
List<int> saveCompilationTrace() {
  final dynamic result = _saveCompilationTrace();
  if (result is Error) throw result;
  return result as List<int>;
}

dynamic _saveCompilationTrace() {
  throw UnimplementedError();
}

int? _getCallbackHandle(Function closure) {
  throw UnimplementedError();
}

Function? _getCallbackFromHandle(int handle) {
  throw UnimplementedError();
}

// Required for gen_snapshot to work correctly.
int? _isolateId; // ignore: unused_element

Function _getPrintClosure() => _print; // ignore: unused_element
