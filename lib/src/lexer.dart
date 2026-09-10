import 'nodes.dart';

const String tagOpen = '<?dag';
const String tagOpenShort = '<?-';
const String tagClose = '?>';

/// Splits a .dag source string into an ordered list of [DagNode]s.
///
/// Recognized tag forms (checked in this order right after `<?dag`):
///   `<?dag:imports ... ?>`  import directives, hoisted to file top
///   `<?dag:params  ... ?>`  render() parameter list
///   `<?dag:name    ... ?>`  render() function name override
///   `<?dag=        ... ?>`  echo a single expression
///   `<?dag         ... ?>`  raw Dart code, inserted verbatim
///
/// Everything outside a tag is literal text emitted as-is.
///
/// Whitespace control (Twig-style, independent on each side): a `-`
/// immediately after the opener strips all trailing whitespace from the
/// text right before the tag; a `-` immediately before `?>` strips all
/// leading whitespace from the text right after the tag. `<?dag-` is the
/// same as `<?-` (a shorthand for the left-trimmed code tag); trims can
/// also combine with `:imports`/`:params`/`:name`/`=`, e.g. `<?dag-= x ?>`
/// or `<?dag- for (...) { -?>`. This is what lets a control tag sit alone
/// on its own line without leaving a blank line in the output.
///
/// Known limitation (shared with PHP): a `?>` occurring inside a Dart
/// string/comment within a tag's own code will be treated as the tag's
/// closing delimiter. Avoid literal `?>` inside `<?dag ?>` code; use a
/// variable or string concatenation instead if you need that sequence.
List<DagNode> lex(String source) {
  final nodes = <DagNode>[];
  var pos = 0;
  var line = 1;
  var trimLeadingOfNextText = false;

  int countNewlines(String s) => '\n'.allMatches(s).length;

  String applyPendingLeftTrim(String text) {
    if (!trimLeadingOfNextText) return text;
    trimLeadingOfNextText = false;
    return text.replaceFirst(RegExp(r'^\s+'), '');
  }

  void trimTrailingOfLastTextNode() {
    if (nodes.isEmpty) return;
    final last = nodes.last;
    if (last is! TextNode) return;
    final trimmed = last.text.replaceFirst(RegExp(r'\s+$'), '');
    if (trimmed != last.text) {
      nodes[nodes.length - 1] = TextNode(trimmed, last.line);
    }
  }

  while (true) {
    final dagIdx = source.indexOf(tagOpen, pos);
    final shortIdx = source.indexOf(tagOpenShort, pos);
    final int start;
    final bool isShort;
    if (dagIdx == -1 && shortIdx == -1) {
      start = -1;
      isShort = false;
    } else if (dagIdx == -1) {
      start = shortIdx;
      isShort = true;
    } else if (shortIdx == -1) {
      start = dagIdx;
      isShort = false;
    } else if (shortIdx < dagIdx) {
      start = shortIdx;
      isShort = true;
    } else {
      start = dagIdx;
      isShort = false;
    }

    if (start == -1) {
      if (pos < source.length) {
        final text = applyPendingLeftTrim(source.substring(pos));
        if (text.isNotEmpty) nodes.add(TextNode(text, line));
      }
      break;
    }

    if (start > pos) {
      final raw = source.substring(pos, start);
      final textLine = line;
      final text = applyPendingLeftTrim(raw);
      if (text.isNotEmpty) nodes.add(TextNode(text, textLine));
      line += countNewlines(raw);
    }

    var cursor = start + (isShort ? tagOpenShort.length : tagOpen.length);
    final tagLine = line;
    var leftTrim = isShort;
    if (!isShort && source.startsWith('-', cursor)) {
      leftTrim = true;
      cursor += 1;
    }
    if (leftTrim) trimTrailingOfLastTextNode();

    String kind = 'code';
    if (source.startsWith(':imports', cursor)) {
      kind = 'imports';
      cursor += ':imports'.length;
    } else if (source.startsWith(':params', cursor)) {
      kind = 'params';
      cursor += ':params'.length;
    } else if (source.startsWith(':name', cursor)) {
      kind = 'name';
      cursor += ':name'.length;
    } else if (source.startsWith('=', cursor)) {
      kind = 'echo';
      cursor += 1;
    }

    var end = source.indexOf(tagClose, cursor);
    if (end == -1) {
      throw FormatException(
        'Unterminated $tagOpen ... $tagClose tag starting at line $tagLine',
      );
    }
    var rightTrim = false;
    if (end > cursor && source[end - 1] == '-') {
      rightTrim = true;
      end -= 1;
    }

    final body = source.substring(cursor, end);
    switch (kind) {
      case 'imports':
        nodes.add(ImportsNode(body, tagLine));
        break;
      case 'params':
        nodes.add(ParamsNode(body.trim(), tagLine));
        break;
      case 'name':
        nodes.add(NameNode(body.trim(), tagLine));
        break;
      case 'echo':
        nodes.add(EchoNode(body.trim(), tagLine));
        break;
      default:
        nodes.add(CodeNode(body, tagLine));
        break;
    }

    trimLeadingOfNextText = rightTrim;

    line += countNewlines(body);
    pos = (rightTrim ? end + 1 : end) + tagClose.length;
  }

  return nodes;
}
