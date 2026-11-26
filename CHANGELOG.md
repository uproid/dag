
## 0.1.3

- Improved error messages for better debugging experience.

## 0.1.2

- Added more examples: a multi-file layout example
  (`example/dag_layouts/`) and a fuller app example
  (`example/example_full_app/`).
- README now points to the
  [FinchDart DAG](https://marketplace.visualstudio.com/items?itemName=uproid.finchdart-dag)
  VS Code extension for syntax highlighting and inline error reporting in
  `.dag` files.

## 0.1.1

- Added `LICENSE` (MIT) and `homepage`/`repository`/`issue_tracker` fields
  to `pubspec.yaml`, required for `pub.dev` publishing.
- Shortened the `pubspec.yaml` `description` to fit pub.dev's recommended
  60-180 character range.
- Widened dependency constraints (`args`, `build`, `path`, `watcher`,
  `build_runner`, `lints`, `test`) to their current latest versions.

## 0.1.0

Initial release.

- Transpile `.dag` files (literal text with embedded Dart, PHP-style) into
  plain `.dart` source. Not a template engine — a `.dag` file compiles to
  real Dart, evaluated at compile time, not interpreted at runtime.
- Tags: `<?dag ... ?>` (raw code, inserted verbatim — can open/close a
  block across multiple tags, e.g. `if (x) {` ... `}`), `<?dag= expr ?>`
  (echo an expression), `<?dag:imports ?>` (deduped, hoisted to file top),
  `<?dag:params ?>` (render function's parameter list), `<?dag:name ?>`
  (rename the generated function, default `render`).
- Generated function is always `Future<String> ... async`, so any echo or
  code can `await` a `Future`/`Future<String>` with no extra setup.
- Runtime errors are rethrown as `DagError`, carrying the original error,
  its stack trace, and the exact `.dag` file + line that caused it — via a
  single `try`/`catch` around the whole function body plus a cheap
  line-tracking variable (no per-statement try/catch overhead).
- Whitespace control: `<?dag- ... ?>` / `<?dag ... -?>` / `<?dag- ... -?>`
  trim adjacent whitespace independently on each side (Twig-style), with
  `<?-` as shorthand for `<?dag-`. Lets structural tags (`for`, `if`, `}`)
  sit on their own line without leaking a blank line into the output.
- `dag` CLI (`dart run dag:dag <file|dir> [--out] [--watch]`) for
  file/directory transpilation with optional watch mode.
- `package:build` `Builder` (`lib/builder.dart`, registered via
  `build.yaml`) so `.dag -> .g.dart` can run through `build_runner` as
  part of a normal Dart build pipeline.
