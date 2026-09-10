/// AST produced by the lexer. A .dag file is a flat sequence of these
/// nodes, in source order — mirroring how a .php file alternates between
/// literal markup and `<?php ... ?>` blocks.
library;

sealed class DagNode {
  final int line;
  const DagNode(this.line);
}

/// Literal text that must be emitted verbatim (outside any `<?dag ?>` tag).
final class TextNode extends DagNode {
  final String text;
  const TextNode(this.text, super.line);
}

/// `<?dag= expr ?>` — a single Dart expression whose value is converted to
/// a string (via string interpolation) and written to the output.
final class EchoNode extends DagNode {
  final String expr;
  const EchoNode(this.expr, super.line);
}

/// `<?dag ... ?>` — raw Dart code inserted verbatim into the generated
/// function body. May be a full statement, a partial statement that opens
/// or closes a block (e.g. `if (x) {` in one tag and `}` in a later tag),
/// a local variable/function declaration, a comment, etc. Exactly like a
/// plain `<?php ... ?>` block.
final class CodeNode extends DagNode {
  final String code;
  const CodeNode(this.code, super.line);
}

/// `<?dag:imports ... ?>` — one Dart import directive per line. All
/// `:imports` blocks in a file are collected, deduplicated (order
/// preserved) and hoisted to the top of the generated .dart file.
final class ImportsNode extends DagNode {
  final String code;
  const ImportsNode(this.code, super.line);
}

/// `<?dag:params ... ?>` — the parameter list of the generated render
/// function, verbatim (e.g. `String name, {int age = 0}`). At most one is
/// expected per file; if several appear they are concatenated with `, `.
final class ParamsNode extends DagNode {
  final String code;
  const ParamsNode(this.code, super.line);
}

/// `<?dag:name Foo ?>` — overrides the generated function's name
/// (default: `render`).
final class NameNode extends DagNode {
  final String code;
  const NameNode(this.code, super.line);
}
