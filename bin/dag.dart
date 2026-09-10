import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:watcher/watcher.dart';

import 'package:dag/dag.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag('watch',
        abbr: 'w',
        negatable: false,
        help: 'Watch for changes and re-transpile.')
    ..addOption('out',
        abbr: 'o',
        help:
            'Output file (single input) or output directory (directory input).')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage.');

  final ArgResults args;
  try {
    args = parser.parse(arguments);
  } on FormatException catch (e) {
    stderr.writeln('dag: ${e.message}\n');
    _printUsage(parser);
    exitCode = 64;
    return;
  }

  if (args['help'] as bool || args.rest.isEmpty) {
    _printUsage(parser);
    exitCode = args['help'] as bool ? 0 : 64;
    return;
  }

  final inputPath = args.rest.first;
  final outArg = args['out'] as String?;
  final watch = args['watch'] as bool;

  final inputType = FileSystemEntity.typeSync(inputPath);
  if (inputType == FileSystemEntityType.notFound) {
    stderr.writeln('dag: no such file or directory: $inputPath');
    exitCode = 66;
    return;
  }

  if (inputType == FileSystemEntityType.directory) {
    await _buildDirectory(inputPath, outArg);
    if (watch) await _watchDirectory(inputPath, outArg);
    return;
  }

  await _buildOne(inputPath, outArg);
  if (watch) await _watchFile(inputPath, outArg);
}

void _printUsage(ArgParser parser) {
  stdout.writeln('Usage: dag <input.dag|directory> [options]\n');
  stdout.writeln(
      'Transpiles .dag files (PHP-style embedded Dart) into plain .dart files.\n');
  stdout.writeln(parser.usage);
}

Future<void> _buildOne(String input, String? out) async {
  try {
    final written = await transpileFile(input, output: out);
    stdout.writeln('dag: $input -> $written');
  } on FormatException catch (e) {
    stderr.writeln('dag: $input: ${e.message}');
    exitCode = 65;
  }
}

Iterable<String> _dagFilesIn(String dir) sync* {
  final d = Directory(dir);
  for (final entity in d.listSync(recursive: true, followLinks: false)) {
    if (entity is File && entity.path.endsWith('.dag')) {
      yield entity.path;
    }
  }
}

String? _mappedOutput(String input, String inputRoot, String? outRoot) {
  if (outRoot == null) return null;
  final rel = p.relative(input, from: inputRoot);
  final relDart = p.setExtension(rel, '.dart');
  return p.join(outRoot, relDart);
}

Future<void> _buildDirectory(String dir, String? outRoot) async {
  var count = 0;
  for (final file in _dagFilesIn(dir)) {
    await _buildOne(file, _mappedOutput(file, dir, outRoot));
    count++;
  }
  stdout.writeln('dag: built $count file(s) from $dir');
}

Future<void> _watchFile(String input, String? out) async {
  stdout.writeln('dag: watching $input for changes...');
  await for (final event in FileWatcher(input).events) {
    if (event.type == ChangeType.MODIFY || event.type == ChangeType.ADD) {
      await _buildOne(input, out);
    }
  }
}

Future<void> _watchDirectory(String dir, String? outRoot) async {
  stdout.writeln('dag: watching $dir for changes...');
  await for (final event in DirectoryWatcher(dir).events) {
    if (!event.path.endsWith('.dag')) continue;
    if (event.type == ChangeType.MODIFY || event.type == ChangeType.ADD) {
      await _buildOne(event.path, _mappedOutput(event.path, dir, outRoot));
    }
  }
}
