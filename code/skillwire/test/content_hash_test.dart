import 'dart:convert';
import 'dart:typed_data';

import 'package:skillwire/skillwire.dart';
import 'package:test/test.dart';

/// The hash is what separates PRD 10.2 state 2 (`keep`) from state 3
/// (`replace`), and it is what R10.6 compares before adopting. It is a pure
/// function of a materialised tree, so it is tested with no filesystem.
void main() {
  Uint8List bytes(String s) => Uint8List.fromList(utf8.encode(s));

  Map<String, Uint8List> tree(Map<String, String> files) =>
      {for (final e in files.entries) e.key: bytes(e.value)};

  group('it hashes the whole tree, not one file', () {
    test('a changed non-SKILL.md file changes the hash', () {
      final a = tree({'SKILL.md': 'x', 'references/R.md': 'one'});
      final b = tree({'SKILL.md': 'x', 'references/R.md': 'two'});
      expect(contentHash(a), isNot(contentHash(b)));
    });

    test('an added file changes the hash', () {
      expect(
        contentHash(tree({'SKILL.md': 'x'})),
        isNot(contentHash(tree({'SKILL.md': 'x', 'a.md': ''}))),
      );
    });

    test('a renamed file changes the hash even with identical bytes', () {
      expect(
        contentHash(tree({'a.md': 'same'})),
        isNot(contentHash(tree({'b.md': 'same'}))),
      );
    });
  });

  group('it is order-independent and separator-independent', () {
    test('insertion order does not matter', () {
      final a = <String, Uint8List>{'b.md': bytes('2'), 'a.md': bytes('1')};
      final b = <String, Uint8List>{'a.md': bytes('1'), 'b.md': bytes('2')};
      expect(contentHash(a), contentHash(b));
    });

    test('a Windows-separated path hashes as its POSIX form', () {
      // G4: two machines given the same manifest reach the same state. A hash
      // that differed by host OS would make that false for every nested file.
      expect(
        contentHash({r'references\R.md': bytes('x')}),
        contentHash({'references/R.md': bytes('x')}),
      );
    });
  });

  group('line endings are normalised for text, and only for text', () {
    test('CRLF and LF hash alike in a .md file', () {
      expect(
        contentHash(tree({'SKILL.md': 'a\r\nb\r\n'})),
        contentHash(tree({'SKILL.md': 'a\nb\n'})),
      );
    });

    test('a lone CR normalises too', () {
      expect(
        contentHash(tree({'SKILL.md': 'a\rb'})),
        contentHash(tree({'SKILL.md': 'a\nb'})),
      );
    });

    test('every declared text extension normalises', () {
      for (final ext in ['md', 'yaml', 'yml', 'json', 'txt']) {
        expect(
          contentHash(tree({'f.$ext': 'a\r\nb'})),
          contentHash(tree({'f.$ext': 'a\nb'})),
          reason: '.$ext did not normalise',
        );
      }
    });

    test('a binary file is hashed raw', () {
      // Normalising an image would corrupt any 0x0D byte in it.
      expect(
        contentHash({'a.png': Uint8List.fromList([1, 13, 10, 2])}),
        isNot(contentHash({'a.png': Uint8List.fromList([1, 10, 2])})),
      );
    });

    test('extension matching is case-insensitive', () {
      expect(
        contentHash(tree({'F.MD': 'a\r\nb'})),
        contentHash(tree({'F.MD': 'a\nb'})),
      );
    });
  });

  group('shape', () {
    test('it is a lowercase 64-character hex digest', () {
      expect(contentHash(tree({'SKILL.md': 'x'})), matches(RegExp(r'^[0-9a-f]{64}$')));
    });

    test('an empty tree has a defined hash, not a crash', () {
      expect(contentHash({}), matches(RegExp(r'^[0-9a-f]{64}$')));
    });

    test('it is stable across calls', () {
      final t = tree({'SKILL.md': 'x'});
      expect(contentHash(t), contentHash(t));
    });

    test('two files cannot be confused by concatenation', () {
      // Without a delimiter, {'ab': '', 'c': 'd'} and {'a': 'bc', ...} could
      // feed the digest identical bytes. The NUL separators prevent it.
      expect(
        contentHash(tree({'ab': '', 'c': 'd'})),
        isNot(contentHash(tree({'a': 'bc', 'd': ''}))),
      );
    });
  });
}
