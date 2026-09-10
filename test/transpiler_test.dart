import 'package:dag/dag.dart';
import 'package:test/test.dart';

void main() {
  group('plain text and echo', () {
    test('text with no tags passes through', () {
      final out = transpile('hello world');
      expect(out, contains('_buf.write("hello world");'));
      expect(out, contains('Future<String> render() async {'));
    });

    test('echo tag embeds via interpolation, on its own write call', () {
      final out = transpile('hello <?dag= 1 + 1 ?>!');
      expect(out, contains('_buf.write("hello ");'));
      expect(out, contains(r'_buf.write("${1 + 1}");'));
      expect(out, contains('_buf.write("!");'));
    });

    test('plain <?dag ?> without = is raw code, not echoed', () {
      final out = transpile('a<?dag var x = 1; ?>b');
      expect(out, contains('var x = 1;'));
      expect(out, isNot(contains(r'${var x = 1;}')));
    });
  });

  group('escaping', () {
    test('escapes quotes, backslashes, dollar signs, newlines', () {
      final out = transpile('a "quote" \\ \$sign\nline2');
      expect(out, contains(r'a \"quote\" \\ \$sign\nline2'));
    });
  });

  group('control flow spanning tags', () {
    test('for loop wraps a write call', () {
      final src = 'before'
          '<?dag for (var i = 0; i < 3; i++) { ?>'
          'x=<?dag= i ?>;'
          '<?dag } ?>'
          'after';
      final out = transpile(src);
      expect(out, contains('for (var i = 0; i < 3; i++) {'));
      expect(out, contains('_buf.write("x=");'));
      expect(out, contains(r'_buf.write("${i}");'));
      expect(out, contains('_buf.write(";");'));
      expect(out, contains('}'));
      expect(out, contains('_buf.write("before");'));
      expect(out, contains('_buf.write("after");'));
    });

    test('nested if/for blocks', () {
      final src = '<?dag if (true) { ?>'
          '<?dag for (var i = 0; i < 2; i++) { ?>'
          'hi'
          '<?dag } ?>'
          '<?dag } ?>';
      final out = transpile(src);
      expect(out, contains('if (true) {'));
      expect(out, contains('for (var i = 0; i < 2; i++) {'));
      expect(out, contains('_buf.write("hi");'));
    });
  });

  group('directives', () {
    test(':imports are deduped and hoisted', () {
      final src =
          "<?dag:imports\nimport 'dart:convert';\nimport 'dart:convert';\n?>"
          "<?dag:imports\nimport 'package:intl/intl.dart';\n?>"
          'body';
      final out = transpile(src);
      final lines = out.split('\n');
      expect(lines.where((l) => l == "import 'dart:convert';").length, 1);
      expect(out, contains("import 'package:intl/intl.dart';"));
      // imports must appear before the function declaration
      expect(out.indexOf("import 'dart:convert';"),
          lessThan(out.indexOf('Future<String> render(')));
    });

    test(':params changes the function signature', () {
      final out = transpile("<?dag:params String name ?>hi <?dag= name ?>");
      expect(out, contains('Future<String> render(String name) async {'));
    });

    test(':name changes the function name', () {
      final out = transpile('<?dag:name renderPage ?>hi');
      expect(out, contains('Future<String> renderPage() async {'));
    });
  });

  test('await works inside an echo interpolation', () {
    final src = "<?dag:imports\nimport 'dart:async';\n?>"
        'v=<?dag= await Future.value(42) ?>';
    final out = transpile(src);
    expect(out, contains(r'_buf.write("${await Future.value(42)}");'));
  });

  group('DagError line tracking', () {
    test('reports the line of the failing echo, not the merged text run', () {
      final out = transpile('line1\nline2\n<?dag= 1 ~/ 0 ?>\nline4');
      expect(out, contains('_dagLine = 1;'));
      expect(out, contains('_dagLine = 3;'));
      expect(out, contains('throw DagError("unknown", _dagLine, e, st);'));
    });

    test('uses sourcePath in the DagError', () {
      final out = transpile('x', sourcePath: 'views/home.dag');
      expect(
          out, contains('throw DagError("views/home.dag", _dagLine, e, st);'));
    });
  });

  group('whitespace control', () {
    test('<?dag- trims preceding whitespace (left trim)', () {
      final out = transpile('before   \n  <?dag- var x = 1; ?>after');
      expect(out, contains('_buf.write("before");'));
      expect(out, contains('var x = 1;'));
    });

    test('-?> trims following whitespace (right trim)', () {
      final out = transpile('before<?dag var x = 1; -?>  \n  after');
      expect(out, contains('var x = 1;'));
      expect(out, contains('_buf.write("after");'));
    });

    test('combined <?dag- ... -?> trims both sides', () {
      final src = 'a\n<?dag- for (var i = 0; i < 2; i++) { -?>\n'
          'x<?dag= i ?>\n'
          '<?dag- } -?>\n'
          'b';
      final out = transpile(src);
      expect(out, contains('_buf.write("a");'));
      expect(out, contains('for (var i = 0; i < 2; i++) {'));
      expect(out, contains('_buf.write("x");'));
      expect(out, contains(r'_buf.write("${i}");'));
      expect(out, contains('_buf.write("b");'));
      // no stray blank-line write calls from the trimmed tag lines
      expect(out, isNot(contains(r'_buf.write("\n");')));
    });

    test('<?- is shorthand for <?dag-', () {
      final out = transpile('before  \n<?- var x = 1; ?>after');
      expect(out, contains('_buf.write("before");'));
      expect(out, contains('var x = 1;'));
    });

    test('trim composes with echo and directive markers', () {
      final out = transpile('a  \n<?dag-= 1 + 1 -?>  \nb');
      expect(out, contains('_buf.write("a");'));
      expect(out, contains(r'_buf.write("${1 + 1}");'));
      expect(out, contains('_buf.write("b");'));
    });
  });

  test('empty echo throws FormatException', () {
    expect(() => transpile('<?dag=  ?>'), throwsFormatException);
  });

  test('unterminated tag throws FormatException', () {
    expect(() => transpile('hello <?dag= 1 + 1'), throwsFormatException);
  });
}
