import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Extensions whose bytes are line-ending-normalised before hashing.
///
/// Anything not listed is hashed raw. Normalising a PNG would rewrite any 0x0D
/// byte in it, so the list is an allow-list rather than a deny-list.
const _textExtensions = {'.md', '.yaml', '.yml', '.json', '.txt'};

/// A stable digest of a materialised artifact directory.
///
/// This is the value PRD 10.2 compares to tell `keep` from `replace`, and the
/// value R10.6 compares before adopting an unledgered directory. It decides
/// whether a user's files are overwritten, so its definition is a contract, not
/// an implementation detail.
///
/// The tree is a map of **relative path** to bytes. It is a pure function: the
/// walk that produces the map lives at the edge, which is what lets every
/// reconciliation state be tested with no disk (R10.4).
///
/// The definition:
///
/// 1. SHA-256.
/// 2. Every file in the tree, sorted lexicographically by its normalised path.
/// 3. Per file the digest absorbs: path bytes, NUL, content bytes, NUL. The
///    separators are what stop `{'ab': '', 'c': 'd'}` and `{'a': 'bc', 'd': ''}`
///    feeding the digest the same stream.
/// 4. Paths are normalised to `/` separators before both sorting and hashing,
///    so a tree hashes alike on Windows and POSIX. Without this, G4 — two
///    machines reaching the same state — would be false for every nested file.
/// 5. Files whose extension is in [_textExtensions] have CRLF and lone CR
///    normalised to LF. This is what makes a CRLF copy on disk hash equal to
///    its LF source, so a checkout that changed line endings does not read as
///    drift.
/// 6. Empty directories are not represented: they carry no content, and a host
///    loading the artifact cannot observe them.
String contentHash(Map<String, Uint8List> tree) {
  final entries = tree.entries
      .map((e) => (path: e.key.replaceAll(r'\', '/'), bytes: e.value))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  // Accumulated rather than streamed: a skill tree is a handful of small text
  // files, and one buffer is clearer than a chunked conversion for that size.
  final buffer = <int>[];
  for (final entry in entries) {
    buffer.addAll(utf8.encode(entry.path));
    buffer.add(0);
    buffer.addAll(_normalise(entry.path, entry.bytes));
    buffer.add(0);
  }
  return sha256.convert(buffer).toString();
}

/// CRLF and lone CR to LF, for text files only.
List<int> _normalise(String path, Uint8List bytes) {
  final dot = path.lastIndexOf('.');
  if (dot < 0) return bytes;
  if (!_textExtensions.contains(path.substring(dot).toLowerCase())) return bytes;

  const cr = 13, lf = 10;
  if (!bytes.contains(cr)) return bytes;

  final out = <int>[];
  for (var i = 0; i < bytes.length; i++) {
    if (bytes[i] == cr) {
      out.add(lf);
      if (i + 1 < bytes.length && bytes[i + 1] == lf) i++;
    } else {
      out.add(bytes[i]);
    }
  }
  return out;
}
