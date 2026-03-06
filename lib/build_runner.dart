// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

Future<void> run(List<String> args) async {
  final result = await Process.run(
    Platform.resolvedExecutable,
    ['run', 'build_runner', ...args],
    runInShell: true,
  );
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  exitCode = result.exitCode;
}
