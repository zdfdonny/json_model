// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:glob/glob.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

final logger = Logger('graph_inspector');

const _assetGraphPath = '.dart_tool/build/asset_graph.json';

Future<void> main(List<String> args) async {
  final logSubscription =
      Logger.root.onRecord.listen((record) => print(record.message));
  logger.warning(
      'Warning: this tool is unsupported and usage may change at any time, '
      'use at your own risk.');

  final argParser = ArgParser()
    ..addOption('graph-file',
        abbr: 'g', help: 'Specify the asset_graph.json file to inspect.')
    ..addOption('build-script',
        abbr: 'b',
        help: 'Specify the build script to find the asset graph for.',
        defaultsTo: '.dart_tool/build/entrypoint/build.dart');

  final results = argParser.parse(args);

  if (results.wasParsed('graph-file') && results.wasParsed('build-script')) {
    throw ArgumentError(
        'Expected exactly one of `--graph-file` or `--build-script`.');
  }

  final graphFilePath = results.wasParsed('graph-file')
      ? results['graph-file'] as String
      : _assetGraphPath;

  final assetGraphFile = File(graphFilePath);
  if (!assetGraphFile.existsSync()) {
    throw ArgumentError(
        'Unable to find asset graph at $graphFilePath. '
        'Run `dart run build_runner build` first.');
  }
  stdout.writeln('Loading asset graph at ${assetGraphFile.path}...');

  final Map<String, dynamic> assetGraph =
      json.decode(assetGraphFile.readAsStringSync()) as Map<String, dynamic>;

  final commandRunner = CommandRunner<bool>(
      '', 'A tool for inspecting the AssetGraph for your build')
    ..addCommand(InspectNodeCommand(assetGraph))
    ..addCommand(GraphCommand(assetGraph))
    ..addCommand(QuitCommand());

  stdout.writeln('Ready, please type in a command:');

  var shouldExit = false;
  while (!shouldExit) {
    stdout
      ..writeln('')
      ..write('> ');
    final nextCommand = stdin.readLineSync();
    stdout.writeln('');
    try {
      shouldExit = await commandRunner.run(nextCommand!.split(' ')) ?? true;
    } on UsageException {
      stdout.writeln('Unrecognized option');
      await commandRunner.run(['help']);
    }
  }
  await logSubscription.cancel();
}

class InspectNodeCommand extends Command<bool> {
  final Map<String, dynamic> assetGraph;

  InspectNodeCommand(this.assetGraph) {
    argParser.addFlag('verbose', abbr: 'v');
  }

  @override
  String get name => 'inspect';

  @override
  String get description =>
      'Lists all the information about an asset using a relative or package: uri';

  @override
  String get invocation => '${super.invocation} <dart-uri>';

  @override
  bool run() {
    final argResults = this.argResults!;
    final stringUris = argResults.rest;
    if (stringUris.isEmpty) {
      stderr.writeln('Expected at least one uri for a node to inspect.');
    }
    final nodes = assetGraph['nodes'] as List? ?? [];
    for (final stringUri in stringUris) {
      final node = nodes.firstWhere(
        (n) => n is Map && n['id'] == stringUri,
        orElse: () => null,
      );
      if (node == null) {
        stderr.writeln('Unable to find an asset node for $stringUri.');
        continue;
      }
      final description = StringBuffer()
        ..writeln('Asset: $stringUri')
        ..writeln('  type: ${node['type'] ?? 'unknown'}');

      if (argResults['verbose'] == true) {
        description.writeln('  details: ${json.encode(node)}');
      }
      stdout.write(description);
    }
    return false;
  }
}

class GraphCommand extends Command<bool> {
  final Map<String, dynamic> assetGraph;

  GraphCommand(this.assetGraph) {
    argParser
      ..addFlag('generated',
          abbr: 'g', help: 'Show only generated assets.', defaultsTo: false)
      ..addFlag('original',
          abbr: 'o',
          help: 'Show only original source assets.',
          defaultsTo: false)
      ..addOption('package',
          abbr: 'p', help: 'Filters nodes to a certain package')
      ..addOption('pattern', abbr: 'm', help: 'glob pattern for path matching');
  }

  @override
  String get name => 'graph';

  @override
  String get description => 'Lists all the nodes in the graph.';

  @override
  String get invocation => '${super.invocation} <dart-uri>';

  @override
  bool run() {
    final argResults = this.argResults!;
    final showGenerated = argResults['generated'] as bool;
    final showSources = argResults['original'] as bool;
    final nodes = (assetGraph['nodes'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();

    Iterable<Map<String, dynamic>> filtered = nodes;
    if (showGenerated) {
      filtered = filtered.where((n) => n['isGenerated'] == true);
    } else if (showSources) {
      filtered = filtered.where((n) => n['isGenerated'] != true);
    }

    final package = argResults['package'] as String?;
    if (package != null) {
      filtered = filtered.where((n) {
        final id = n['id'] as String?;
        return id != null && id.startsWith('$package|');
      });
    }

    final pattern = argResults['pattern'] as String?;
    Glob? glob;
    if (pattern != null) {
      glob = Glob(pattern);
    }

    for (final node in filtered) {
      final id = node['id'] as String? ?? 'unknown';
      if (glob != null) {
        final path = id.contains('|') ? id.split('|').last : id;
        if (!glob.matches(path)) continue;
      }
      _listNode(id, stdout);
    }
    return false;
  }
}

class QuitCommand extends Command<bool> {
  @override
  String get name => 'quit';

  @override
  String get description => 'Exit the inspector';

  @override
  bool run() => true;
}

void _listNode(String id, StringSink buffer, {String indentation = '  '}) {
  if (id.startsWith('package:') || id.contains('|')) {
    final parts = id.split('|');
    if (parts.length == 2) {
      buffer.writeln('${indentation}package:${parts[0]}/${parts[1]}');
    } else {
      buffer.writeln('$indentation$id');
    }
  } else {
    buffer.writeln('$indentation${p.normalize(id)}');
  }
}
