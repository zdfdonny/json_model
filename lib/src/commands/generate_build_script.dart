// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

const scriptLocation = '.dart_tool/build/entrypoint/build.dart';

class GenerateBuildScript extends Command<int> {
  @override
  String get description =>
      'Generate a script to run builds and print the file path '
      'with no other logging. Useful for wrapping builds with other tools.';

  @override
  String get name => 'generate-build-script';

  @override
  bool get hidden => true;

  @override
  Future<int> run() async {
    final result = await Process.run(
      Platform.resolvedExecutable,
      ['run', 'build_runner', 'generate-build-script'],
      runInShell: true,
    );
    stdout.write(result.stdout);
    stderr.write(result.stderr);
    if (result.exitCode == 0) {
      print(p.absolute(scriptLocation));
    }
    return result.exitCode;
  }
}
