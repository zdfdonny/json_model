// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

class CleanCommand extends Command<int> {
  @override
  String get name => 'clean';

  @override
  String get description =>
      'Cleans up output from previous builds. Does not clean up --output '
      'directories.';

  @override
  Future<int> run() async {
    final cacheDir = Directory(p.join('.dart_tool', 'build'));
    if (cacheDir.existsSync()) {
      cacheDir.deleteSync(recursive: true);
      stdout.writeln('Deleted ${cacheDir.path}');
    } else {
      stdout.writeln('Nothing to clean.');
    }
    return 0;
  }
}
