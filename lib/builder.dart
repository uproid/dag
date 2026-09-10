/// build_runner integration: transpiles `.dag` -> `.g.dart` as part of the
/// standard Dart build pipeline, alongside (not instead of) the `dag` CLI.
library;

import 'package:build/build.dart';

import 'src/transpiler.dart';

Builder dagBuilder(BuilderOptions options) => _DagBuilder();

class _DagBuilder implements Builder {
  @override
  Map<String, List<String>> get buildExtensions => const {
        '.dag': ['.g.dart'],
      };

  @override
  Future<void> build(BuildStep buildStep) async {
    final inputId = buildStep.inputId;
    final source = await buildStep.readAsString(inputId);
    final dart = transpile(source, sourcePath: inputId.path);
    await buildStep.writeAsString(inputId.changeExtension('.g.dart'), dart);
  }
}
