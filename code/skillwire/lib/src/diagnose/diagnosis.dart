import '../domain/scope.dart';
import '../domain/unit.dart';
import '../ledger/ledger.dart';

/// A host that reads a directory, at a scope.
typedef HostScope = (String host, Scope scope);

/// What the ledger says about one unit, checked against the world.
enum LedgerClaim {
  /// Recorded, present, and holding what was recorded.
  intact,

  /// Recorded, but nothing is at the destination any more.
  ///
  /// Distinct from [drifted], and the distinction is the point: an absent
  /// directory hashes as an empty tree, which differs from what was recorded,
  /// so without this it reads as "modified at the destination" — and the remedy
  /// for that is the opposite of the remedy for this.
  missing,

  /// Recorded and present, but holding something else. Someone edited it, and
  /// deploying would lose their work, so deploy blocks (PRD 10.2 state 4).
  drifted,

  /// Recorded by a different consumer. Left alone, with or without `--force`
  /// (R10.3, state 5).
  foreign,
}

/// One ledger row, and what became of it.
class ClaimedUnit {
  const ClaimedUnit({
    required this.unit,
    required this.row,
    required this.claim,
  });

  final Unit unit;
  final LedgerRow row;
  final LedgerClaim claim;

  /// What to do about it, in the user's terms.
  ///
  /// Carried per claim rather than printed once per section, because the wrong
  /// remedy beside a correct finding is worse than no remedy: it sends the
  /// reader somewhere the tool already knows is not the answer.
  String get remedy => switch (claim) {
    LedgerClaim.intact => 'nothing to do',
    LedgerClaim.missing =>
      'gone from the destination; an ordinary deploy will recreate it',
    LedgerClaim.drifted =>
      'edited since it was deployed; deploy will block rather than lose the '
          'edits — keep them, or remove the artifact and deploy again',
    LedgerClaim.foreign =>
      'owned by ${row.owningConsumer}; this consumer will not touch it',
  };
}

/// A directory found in a place a host reads.
class FoundArtifact {
  const FoundArtifact({
    required this.path,
    required this.name,
    required this.declaredOrigin,
    required this.readBy,
  });

  /// The physical directory. Identity is the path, not a `(host, scope)` tuple:
  /// `~/.claude/skills` sits in OpenCode's observed set as well as Claude's, and
  /// keying on the tuple would report one directory twice and invent a second
  /// problem out of a single fact.
  final String path;

  final String name;

  /// `metadata.skillwire-origin`, when the artifact declares one.
  ///
  /// **Not ownership** (R13.8). Anyone can type it into a file. It lets a report
  /// say who *appears* to have put a directory somewhere instead of only that
  /// nobody recorded it.
  final String? declaredOrigin;

  /// Every detected host that reads this path, and at what scope.
  final List<HostScope> readBy;
}

/// A directory in a host's reach that no consumer recorded.
class UnmanagedArtifact {
  const UnmanagedArtifact({required this.found});

  final FoundArtifact found;

  String get path => found.path;
  String get name => found.name;
  String? get declaredOrigin => found.declaredOrigin;
  List<HostScope> get readBy => found.readBy;

  String get summary => declaredOrigin == null
      ? '$name — no consumer recorded it, and it declares no origin'
      : '$name — no consumer recorded it; appears to be from $declaredOrigin';
}

/// The same artifact name in more than one directory a single host reads.
///
/// R7.5's collision: not a filesystem clash, but two things the user can invoke
/// that both claim to be the same skill.
class DuplicateArtifact {
  const DuplicateArtifact({
    required this.artifact,
    required this.host,
    required this.scope,
    required this.paths,
    required this.isExpected,
  });

  final String artifact;
  final String host;
  final Scope scope;
  final List<String> paths;

  /// Whether this arrangement is the irreducible one PRD 7.4 describes.
  ///
  /// Deploying to Claude Code and OpenCode at global scope necessarily puts an
  /// artifact where OpenCode sees it twice, because OpenCode reads
  /// `~/.claude/skills` and cannot be prevented. No arrangement of deployments
  /// avoids it, so presenting it as a fault would be telling the user off for
  /// the ecosystem. R7.6 annotates it in the plan instead; here it is stated and
  /// set aside.
  final bool isExpected;

  String get summary => isExpected
      ? '$artifact is visible to $host from ${paths.length} directories; '
            'irreducible at ${scope.token} scope (PRD 7.4)'
      : '$artifact is visible to $host from ${paths.length} directories, and '
            'need not be';
}

/// Everything `skill doctor` found.
class Diagnosis {
  const Diagnosis({
    required this.allClaims,
    required this.unmanaged,
    required this.duplicates,
  });

  final List<ClaimedUnit> allClaims;
  final List<UnmanagedArtifact> unmanaged;
  final List<DuplicateArtifact> duplicates;

  List<ClaimedUnit> claims(LedgerClaim claim) =>
      [for (final c in allClaims) if (c.claim == claim) c];

  /// Duplicates somebody can actually do something about.
  List<DuplicateArtifact> get actionableDuplicates =>
      [for (final d in duplicates) if (!d.isExpected) d];

  /// Whether the machine matches what the ledger believes.
  ///
  /// Unmanaged occupants and other consumers' artifacts do **not** make it
  /// false. Five macss skills beside ours is an ordinary machine, and telling a
  /// user it is unhealthy because another tool also uses it would teach them to
  /// ignore the word.
  bool get isHealthy =>
      claims(LedgerClaim.missing).isEmpty &&
      claims(LedgerClaim.drifted).isEmpty &&
      actionableDuplicates.isEmpty;
}

/// Classify a machine against the ledger. Pure.
///
/// [destinationHashes] maps each ledger row's destination to what is there now,
/// or null when nothing is. [found] is every artifact directory seen in a place
/// a detected host reads. Both are produced by a scan at the edge, which is what
/// keeps every rule below testable with no disk.
Diagnosis diagnose({
  required Ledger ledger,
  required String actingConsumer,
  required Map<String, String?> destinationHashes,
  required List<FoundArtifact> found,
}) {
  final claims = <ClaimedUnit>[];
  final managedPaths = <String>{};

  for (final entry in ledger.rows.entries) {
    final row = entry.value;
    managedPaths.add(row.resolvedDestinationPath);

    final LedgerClaim claim;
    if (row.owningConsumer != actingConsumer) {
      // Whether another consumer's artifact still matches what that consumer
      // recorded is that consumer's business, and reporting it would invite
      // acting on it.
      claim = LedgerClaim.foreign;
    } else {
      final actual = destinationHashes[row.resolvedDestinationPath];
      claim = actual == null
          ? LedgerClaim.missing
          : actual == row.contentHash
              ? LedgerClaim.intact
              : LedgerClaim.drifted;
    }
    claims.add(ClaimedUnit(unit: entry.key, row: row, claim: claim));
  }

  claims.sort((a, b) => a.unit.key.compareTo(b.unit.key));

  final unmanaged = [
    for (final f in found)
      if (!managedPaths.contains(f.path)) UnmanagedArtifact(found: f),
  ]..sort((a, b) => a.path.compareTo(b.path));

  return Diagnosis(
    allClaims: claims,
    unmanaged: unmanaged,
    duplicates: _duplicates(found, managedPaths),
  );
}

/// Group by what a single host sees, and report a name it sees more than once.
List<DuplicateArtifact> _duplicates(
  List<FoundArtifact> found,
  Set<String> managedPaths,
) {
  final byHostScopeName = <(String, Scope, String), Set<String>>{};
  for (final f in found) {
    for (final (host, scope) in f.readBy) {
      byHostScopeName.putIfAbsent((host, scope, f.name), () => {}).add(f.path);
    }
  }

  final out = <DuplicateArtifact>[];
  for (final entry in byHostScopeName.entries) {
    if (entry.value.length < 2) continue;
    final (host, scope, artifact) = entry.key;
    final paths = entry.value.toList()..sort();
    out.add(
      DuplicateArtifact(
        artifact: artifact,
        host: host,
        scope: scope,
        paths: paths,
        // Every copy ledgered means every copy was deployed deliberately, and
        // what the host sees is the consequence PRD 7.4 says cannot be avoided.
        // One copy nobody recorded means somebody can remove it.
        isExpected: paths.every(managedPaths.contains),
      ),
    );
  }

  out.sort((a, b) {
    final byName = a.artifact.compareTo(b.artifact);
    return byName != 0 ? byName : a.host.compareTo(b.host);
  });
  return out;
}
