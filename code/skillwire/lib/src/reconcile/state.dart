import 'dart:typed_data';

import '../hash/content_hash.dart' as hash;

/// The verbs a plan can carry.
///
/// `preview_executor` types a verb as a free string on purpose — it cannot know
/// the vocabulary of every domain, and a closed set would force `other`. This
/// class is that vocabulary for this domain, named once so no call site spells
/// `replace` two ways.
abstract final class Verb {
  /// PRD 10.2 state 1. Nothing at the destination.
  static const create = 'create';

  /// State 2. Ours, hash matches. No action.
  static const keep = 'keep';

  /// State 3. Ours, hash differs. Deploy over it.
  static const replace = 'replace';

  /// States 4, 5, 6. Something is in the way that this run must not disturb.
  static const block = 'block';

  /// R10.6. A state 6 unit whose hash matches, under `--force`: the ledger
  /// gains a row and the destination is not touched.
  static const adopt = 'adopt';

  /// A removal that will happen.
  static const remove = 'remove';

  /// A removal with nothing to remove.
  static const absent = 'absent';
}

/// What reconciliation is being asked to do.
enum Operation { deploy, remove }

/// A ledger row as reconciliation needs to see it.
///
/// The full row (R11.3) carries source, destination, version and timestamps;
/// none of that changes a verb, so none of it appears here. Keeping the
/// decision's input this narrow is what makes the decision easy to reason about.
class LedgerRecord {
  const LedgerRecord({required this.owner, required this.contentHash});

  /// The consumer that deployed this unit. Ownership lives here and nowhere
  /// else — not in a filename prefix, and not in a `skillwire-origin` key,
  /// which anyone can type (R13.8).
  final String owner;

  /// The hash of what that consumer wrote. Compared against what is on disk to
  /// tell state 2/3 from state 4.
  final String contentHash;

  @override
  bool operator ==(Object other) =>
      other is LedgerRecord &&
      other.owner == owner &&
      other.contentHash == contentHash;

  @override
  int get hashCode => Object.hash(owner, contentHash);
}

/// What the world says about one unit, read once before planning.
class Observed {
  const Observed({this.contentHash, this.ledger});

  /// The hash of what is at the destination, or null when nothing is there.
  final String? contentHash;

  /// The ledger row for this unit, or null when no consumer recorded it.
  final LedgerRecord? ledger;

  bool get isPresent => contentHash != null;
}

/// What this run wants at a destination.
///
/// Carries the materialised tree rather than a path to it. The bytes are
/// resolved once, when the plan is built, so the preview and the work cannot
/// describe different changes — deriving the same answer twice is exactly how
/// they come apart.
class Desired {
  Desired({required this.tree, required this.destination})
    : contentHash = hash.contentHash(tree);

  /// Relative path to bytes. Produced by materialisation, which reconciliation
  /// knows nothing about (R8.1).
  final Map<String, Uint8List> tree;

  /// The resolved absolute destination directory.
  final String destination;

  /// Computed at construction, never recomputed.
  final String contentHash;
}
