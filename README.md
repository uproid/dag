# dag

Transpiles `.dag` files into plain `.dart` files. A `.dag` file mixes
literal output text with real, embedded Dart code — the same relationship
a `.php` file has to PHP. **This is not a template engine**: nothing is
interpreted at runtime. `dag` only rewrites `.dag` source into equivalent
`.dart` source, which you then compile/run normally.

## VS Code extension

For syntax highlighting of embedded Dart code and inline error reporting
in `.dag` files, install the
[FinchDart DAG](https://marketplace.visualstudio.com/items?itemName=uproid.finchdart-dag)
extension from the VS Code Marketplace.

## Tags

| Tag | Meaning |
|---|---|
| `<?dag ... ?>` | Raw Dart code, inserted verbatim into the generated function body. Can be a full statement, or a fragment that opens/closes a block across multiple tags (`if (x) {` ... later ... `}`) — exactly like `<?php ?>`. |
| `<?dag= expr ?>` | Echoes a single Dart expression (via string interpolation). |
| `<?dag:imports ... ?>` | One Dart `import` per line. Collected from anywhere in the file, deduplicated, and hoisted to the top of the generated file. |
| `<?dag:params ... ?>` | The parameter list of the generated function, e.g. `String name, {int age = 0}`. |
| `<?dag:name Foo ?>` | Overrides the generated function's name (default `render`). |

Everything outside a tag is literal text, written to the output exactly as
it appears (newlines included).

### Whitespace control

A `-` right after the opener strips *all* adjacent whitespace (spaces,
tabs, newlines — not just up to the next line) from the text immediately
before the tag; a `-` right before `?>` does the same to the text right
after it. The two sides are independent, so you can trim one, the other,
or both:

```
<?dag- ... ?>     trim before the tag only
<?dag ... -?>     trim after the tag only
<?dag- ... -?>    trim both sides
<?- ... ?>        shorthand for <?dag- ... ?>
```

This is what lets a structural tag (`for`, `if`, the closing `}`) sit alone
on its own line in the `.dag` file without that line's newline leaking
into the output:

```
<?dag- for (final item in items) { -?>
 - <?dag= item ?>
<?dag- } -?>
```

The trim markers compose with `=`/`:imports`/`:params`/`:name` too, e.g.
`<?dag-= expr -?>`.

## Example

`greeting.dag`:

```
<?dag:imports
import 'dart:core';
?>
<?dag:params String name, List<String> items ?>
Hello <?dag= name ?>, today is <?dag= DateTime.now().toIso8601String() ?>.

<?dag if (items.isEmpty) { ?>
You have no items.
<?dag } else { ?>
Your items:
<?dag for (final item in items) { ?>
 - <?dag= item ?>
<?dag } ?>
<?dag } ?>
```

transpiles to `greeting.dart`:

```dart
import 'dart:core';

Future<String> render(String name, List<String> items) async {
  final _buf = StringBuffer();
  _buf.write("\nHello ${name}, today is ${DateTime.now().toIso8601String()}.\n\n");
  if (items.isEmpty) {
    _buf.write("\nYou have no items.\n");
  } else {
    _buf.write("\nYour items:\n");
    for (final item in items) {
      _buf.write("\n - ${item}\n");
    }
    _buf.write("\n");
  }
  return _buf.toString();
}
```

The generated function is always `Future<String> ... async`, so any
`<?dag= ?>` echo — or any raw `<?dag ?>` code — can freely use `await` on a
`Future`/`Future<String>`, e.g. `<?dag= await fetchUser() ?>`, without any
extra setup. Call sites just need `await render(...)` (or `.then(...)`).

Because tag bodies are inserted verbatim, anything Dart allows nests
however deep you like: `if`/`else if`/`else`, `for`/`while`/`do`, `switch`,
`try`/`catch`/`finally`, local variables, local functions, comments — all
work across tag boundaries just like in PHP.

## CLI

```
dart run dag:dag <input.dag|directory> [--out <path>] [--watch]
```

- Single file: `dart run dag:dag lib/views/home.dag` writes
  `lib/views/home.dart` next to it (or `--out custom_name.dart`).
- Directory: `dart run dag:dag lib/views --out lib/generated` recursively
  transpiles every `*.dag` file, mirroring the directory structure under
  `--out` (defaults to writing `.dart` next to each `.dag`).
- Add `--watch` to keep re-transpiling on save.

## build_runner

`dag` also ships a `package:build` `Builder` so `.dag -> .g.dart` can run as
part of a normal Dart build pipeline instead of (or alongside) the CLI:

```
dart pub add dag
dart pub add dev:build_runner
dart run build_runner build --delete-conflicting-outputs
# or, while developing:
dart run build_runner watch --delete-conflicting-outputs
```

Every `foo.dag` produces `foo.g.dart` next to it, importable like any
generated file:

```dart
import 'foo.g.dart';

Future<void> main() async => print(await render('World', []));
```

`build.yaml` registers the builder with `auto_apply: root_package`, so
`.dag` files anywhere in *this* package are picked up automatically. If you
instead depend on `dag` from a separate app/package and want its `.dag`
files built too, change (or add, in your own `build.yaml`) `auto_apply` to
`dependents` or `all_packages` — `root_package` only applies the builder to
the package that literally owns this `build.yaml`, not to packages that
depend on it. The standalone `dag` CLI above remains available for projects
that don't use build_runner at all, or that want the output named
`foo.dart` instead of `foo.g.dart`.

## Error locations (`DagError`)

The whole generated function body runs inside one `try`/`catch` — not one
per line, so there's no meaningful runtime overhead. Before each output
write or raw code statement, a cheap `_dagLine = N;` assignment records
where execution currently is. If anything throws, it's rethrown as a
[`DagError`](lib/src/dag_error.dart) that carries the original error, its
stack trace, and the exact `.dag` file + line that caused it — so you don't
have to map a stack trace pointing into generated `.g.dart`/`.dart` code
back to the `.dag` source by hand:

```dart
try {
  await render(...);
} on DagError catch (e) {
  print(e); // DagError: ... \n  at views/home.dag:12 (generated by package:dag)
}
```

## Library API

```dart
import 'package:dag/dag.dart';

final dartSource = transpile(dagSource);           // String -> String (transpiles, doesn't run anything)
final writtenPath = await transpileFile('a.dag');   // reads + writes a file
```

## Known limitation

A literal `?>` inside a tag's own Dart code (e.g. inside a string or
comment) closes the tag early — the same footgun PHP has. Avoid writing
`?>` inside `<?dag ?>` code; build it from a variable or concatenation
instead if you ever need that exact character sequence.
