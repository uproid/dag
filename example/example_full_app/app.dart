/// Full app example using the `style` module.
/// See the source on GitHub:
/// https://github.com/uproid/dag/blob/main/example/example_full_app/style.dag

import 'style.g.dart' as style;

void main() async {
  print(await style.main([
    "Hello",
    "World",
    "Dart",
    "Dag",
    "Long word",
    "is geen nettigheid maar noodzaak",
  ]));
}
