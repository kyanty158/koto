import 'package:flutter_test/flutter_test.dart';
import 'package:koto/utils/tags.dart';

void main() {
  group('extractInlineTags', () {
    test('extracts simple tags and lowercases', () {
      expect(extractInlineTags('#Foo #bar'), ['bar', 'foo']);
    });

    test('requires boundary before #', () {
      // no space before # -> not matched at mid-word
      expect(extractInlineTags('hello#foo'), <String>[]);
    });

    test('allows hyphen and underscore', () {
      expect(extractInlineTags('#a-b_c #A'), ['a', 'a-b_c']);
    });

    test('deduplicates and sorts', () {
      expect(extractInlineTags('#b #a #b'), ['a', 'b']);
    });
  });
}

