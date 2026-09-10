/// Transpiles `.dag` files — plain text with embedded Dart code in
/// `<?dag ... ?>` tags, PHP-style — into plain `.dart` source files.
///
/// This is not a template engine: a `.dag` file *is* Dart source, the same
/// way a `.php` file is PHP source. Everything outside a tag is literal
/// output text; everything inside a tag is real Dart code, inserted
/// verbatim into the generated function, so `if`/`for`/`while`/`switch`/
/// local declarations/comments/etc. all nest and interleave with output
/// text exactly like they do in PHP.
library;

import 'dart:io';

export 'src/dag_error.dart' show DagError;
export 'src/transpiler.dart' show transpile;

import 'src/transpiler.dart' show transpile;

/// Reads [input], transpiles it, and writes the result to [output]
/// (defaults to [input] with its extension changed to `.dart`).
///
/// Returns the path that was written.
Future<String> transpileFile(String input, {String? output}) async {
  final inputFile = File(input);
  final source = await inputFile.readAsString();
  final dart = transpile(source, sourcePath: input);
  final outPath = output ?? _defaultOutputPath(input);
  final outFile = File(outPath);
  await outFile.parent.create(recursive: true);
  await outFile.writeAsString(dart);
  return outPath;
}

String _defaultOutputPath(String input) {
  if (input.endsWith('.dag')) {
    return '${input.substring(0, input.length - '.dag'.length)}.dart';
  }
  return '$input.dart';
}
