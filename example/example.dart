import 'dag_layouts/greeting.g.dart' as greeting;

Future<void> main() async {
  print(await greeting.render(items: [
    "item1",
    "item2",
    "item3",
    "item4",
    "item5",
  ]));
}
