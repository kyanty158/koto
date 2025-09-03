/// Utilities for inline tag extraction.
/// Extracts words that start with `#` at the beginning of text or after a whitespace.
/// Allowed characters: A–Z a–z 0–9 underscore `_` and hyphen `-`.
/// Returns lowercased, unique, sorted list.
List<String> extractInlineTags(String text) {
  final reg = RegExp(r'(^|\s)#([A-Za-z0-9_\-]+)');
  final found = <String>{};
  for (final m in reg.allMatches(text)) {
    if (m.groupCount >= 2) {
      final tag = m.group(2)!;
      if (tag.isNotEmpty) {
        found.add(tag.toLowerCase());
      }
    }
  }
  final list = found.toList()..sort();
  return list;
}

