import 'package:skillwire/skillwire.dart';
import 'package:test/test.dart';

/// What `skill doctor` decides, as a pure function.
///
/// Doctor's question is not "what did I deploy" — that is the ledger, and it
/// can answer it alone. It is: **is what the ledger believes about this machine
/// still true, and is anything here that the ledger does not know about?**
///
/// No `dart:io`: the scan that produces the inputs lives at the CLI's edge.
void main() {
  const acting = 'skillwire_cli';

  Unit unit(String artifact, {String host = 'claude'}) => Unit(
    artifact: artifact,
    kind: Kind.skill,
    host: host,
    scope: Scope.global,
  );

  LedgerRow row({
    required String destination,
    required String hash,
    String owner = acting,
  }) => LedgerRow(
    sourceType: SourceType.local,
    sourceReference: 'assets',
    resolvedDestinationPath: destination,
    contentHash: hash,
    owningConsumer: owner,
    artifactVersion: '1.0.0',
    created: DateTime.utc(2026),
    updated: DateTime.utc(2026),
  );

  Diagnosis run({
    Map<Unit, LedgerRow> rows = const {},
    Map<String, String?> onDisk = const {},
    List<FoundArtifact> found = const [],
  }) {
    final ledger = Ledger();
    rows.forEach(ledger.put);
    return diagnose(
      ledger: ledger,
      actingConsumer: acting,
      destinationHashes: onDisk,
      found: found,
    );
  }

  List<String> artifactsIn(List<ClaimedUnit> claims) =>
      claims.map((c) => c.unit.artifact).toList()..sort();

  group('what the ledger claims', () {
    test('recorded, present and matching is intact', () {
      final d = run(
        rows: {unit('legion'): row(destination: '/d/legion', hash: 'h')},
        onDisk: {'/d/legion': 'h'},
      );
      expect(artifactsIn(d.claims(LedgerClaim.intact)), ['legion']);
      expect(d.claims(LedgerClaim.drifted), isEmpty);
    });

    test('recorded, present, different hash is drifted', () {
      final d = run(
        rows: {unit('legion'): row(destination: '/d/legion', hash: 'h')},
        onDisk: {'/d/legion': 'other'},
      );
      expect(artifactsIn(d.claims(LedgerClaim.drifted)), ['legion']);
    });

    test('recorded but NOT on disk is missing, not drifted', () {
      // The defect this test exists for: an absent directory hashes as an empty
      // tree, which differs from what was recorded, so it read as "modified at
      // the destination" and the remedy printed beside it was the opposite of
      // the right one. Nothing was modified and nothing would be lost.
      final d = run(
        rows: {unit('legion'): row(destination: '/d/legion', hash: 'h')},
        onDisk: {'/d/legion': null},
      );
      expect(artifactsIn(d.claims(LedgerClaim.missing)), ['legion']);
      expect(d.claims(LedgerClaim.drifted), isEmpty);
    });

    test('missing and drifted carry different remedies', () {
      final d = run(
        rows: {
          unit('legion'): row(destination: '/d/legion', hash: 'h'),
          unit('kritik'): row(destination: '/d/kritik', hash: 'h'),
        },
        onDisk: {'/d/legion': null, '/d/kritik': 'other'},
      );
      final missing = d.claims(LedgerClaim.missing).single;
      final drifted = d.claims(LedgerClaim.drifted).single;
      expect(missing.remedy, isNot(drifted.remedy));
      // A missing unit is recreated by an ordinary deploy; a drifted one is
      // blocked by it, which is the whole difference.
      expect(missing.remedy, contains('deploy'));
      expect(drifted.remedy, contains('block'));
    });

    test('another consumer owns it, whatever the disk says', () {
      final d = run(
        rows: {
          unit('macss-plan'): row(
            destination: '/d/macss-plan',
            hash: 'h',
            owner: 'macss',
          ),
        },
        onDisk: {'/d/macss-plan': 'anything'},
      );
      expect(artifactsIn(d.claims(LedgerClaim.foreign)), ['macss-plan']);
      expect(d.claims(LedgerClaim.drifted), isEmpty);
    });

    test('a foreign row is never reported as drift', () {
      // Whether another consumer's artifact matches what that consumer recorded
      // is that consumer's business. Reporting it would invite acting on it.
      final d = run(
        rows: {
          unit('macss-plan'): row(
            destination: '/d/m',
            hash: 'recorded',
            owner: 'macss',
          ),
        },
        onDisk: {'/d/m': 'changed'},
      );
      expect(d.claims(LedgerClaim.foreign), hasLength(1));
      expect(d.claims(LedgerClaim.drifted), isEmpty);
      expect(d.claims(LedgerClaim.missing), isEmpty);
    });

    test('every claimed unit falls in exactly one bucket', () {
      final d = run(
        rows: {
          unit('a'): row(destination: '/d/a', hash: 'h'),
          unit('b'): row(destination: '/d/b', hash: 'h'),
          unit('c'): row(destination: '/d/c', hash: 'h'),
          unit('e'): row(destination: '/d/e', hash: 'h', owner: 'macss'),
        },
        onDisk: {'/d/a': 'h', '/d/b': 'x', '/d/c': null, '/d/e': 'h'},
      );
      expect(d.allClaims, hasLength(4));
      expect(
        LedgerClaim.values
            .expand((c) => d.claims(c))
            .map((c) => c.unit)
            .toSet(),
        hasLength(4),
      );
    });
  });

  group('what the ledger does not know', () {
    FoundArtifact found(
      String path,
      String name, {
      String? origin,
      List<(String, Scope)> readBy = const [('claude', Scope.global)],
    }) => FoundArtifact(
      path: path,
      name: name,
      declaredOrigin: origin,
      readBy: readBy,
    );

    test('a directory nobody recorded is unmanaged', () {
      final d = run(found: [found('/d/macss-plan', 'macss-plan')]);
      expect(d.unmanaged.map((u) => u.name), ['macss-plan']);
    });

    test('a directory the ledger records is not unmanaged', () {
      final d = run(
        rows: {unit('legion'): row(destination: '/d/legion', hash: 'h')},
        onDisk: {'/d/legion': 'h'},
        found: [found('/d/legion', 'legion')],
      );
      expect(d.unmanaged, isEmpty);
    });

    test('a row belonging to another consumer still manages its directory', () {
      // It is unmanaged by *nobody*, not unmanaged by us. Reporting macss's own
      // deployment as an unknown occupant would be a lie about the machine.
      final d = run(
        rows: {
          unit('macss-plan'): row(
            destination: '/d/macss-plan',
            hash: 'h',
            owner: 'macss',
          ),
        },
        onDisk: {'/d/macss-plan': 'h'},
        found: [found('/d/macss-plan', 'macss-plan')],
      );
      expect(d.unmanaged, isEmpty);
    });

    test('a declared origin is reported as appearance, not as ownership', () {
      // R13.8 - anyone can type skillwire-origin into a file. It lets the report
      // say who *appears* to have put a directory there instead of only that
      // nobody recorded it.
      final d = run(
        found: [found('/d/x', 'x', origin: 'macss')],
      );
      expect(d.unmanaged.single.declaredOrigin, 'macss');
      expect(d.unmanaged.single.summary, contains('appears'));
    });

    test('with no declared origin it says so plainly', () {
      final d = run(found: [found('/d/x', 'x')]);
      expect(d.unmanaged.single.declaredOrigin, isNull);
      expect(d.unmanaged.single.summary, isNot(contains('appears')));
    });

    test('one physical directory is reported once, however many hosts read it', () {
      // ~/.claude/skills is in OpenCode's observed set as well as Claude's. A
      // scan that keyed on (host, scope) would report the same directory twice
      // and invent a second problem.
      final d = run(
        found: [
          found('/home/.claude/skills/x', 'x', readBy: [
            ('claude', Scope.global),
            ('opencode', Scope.global),
          ]),
        ],
      );
      expect(d.unmanaged, hasLength(1));
      expect(d.unmanaged.single.readBy.map((r) => r.$1), ['claude', 'opencode']);
    });

    test('unmanaged directories are reported in path order', () {
      final d = run(
        found: [found('/d/z', 'z'), found('/d/a', 'a'), found('/d/m', 'm')],
      );
      expect(d.unmanaged.map((u) => u.name), ['a', 'm', 'z']);
    });
  });

  group('R7.5 - one artifact, one directory per host', () {
    FoundArtifact at(String path, String name, List<(String, Scope)> readBy) =>
        FoundArtifact(path: path, name: name, declaredOrigin: null, readBy: readBy);

    test('the same name in two directories one host reads is a duplicate', () {
      // OpenCode resolves its own tree with {skill,skills}, so both spellings
      // are read under one invocation name (R6.5). Two copies are two things
      // the user can invoke claiming to be the same skill.
      final d = run(
        found: [
          at('/home/.config/opencode/skill/legion', 'legion', [('opencode', Scope.global)]),
          at('/home/.config/opencode/skills/legion', 'legion', [('opencode', Scope.global)]),
        ],
      );
      expect(d.duplicates, hasLength(1));
      final dup = d.duplicates.single;
      expect(dup.artifact, 'legion');
      expect(dup.host, 'opencode');
      expect(dup.paths, hasLength(2));
    });

    test('one copy is not a duplicate', () {
      final d = run(
        found: [at('/d/legion', 'legion', [('opencode', Scope.global)])],
      );
      expect(d.duplicates, isEmpty);
    });

    test('two hosts each holding one copy is not a duplicate', () {
      final d = run(
        found: [
          at('/home/.claude/skills/legion', 'legion', [('claude', Scope.global)]),
          at('/home/.config/opencode/skills/legion', 'legion', [('opencode', Scope.global)]),
        ],
      );
      expect(d.duplicates, isEmpty);
    });

    test('the deliberate two-host deployment is expected, not a hazard', () {
      // Deploying to claude and opencode at global scope puts legion in both
      // ~/.claude/skills and ~/.config/opencode/skills, and OpenCode reads
      // both. PRD 7.4 calls that irreducible and R7.6 annotates it. It is not
      // something doctor should present as a fault, because there is no
      // arrangement of deployments that avoids it.
      final d = run(
        rows: {
          unit('legion'): row(destination: '/home/.claude/skills/legion', hash: 'h'),
          unit('legion', host: 'opencode'):
              row(destination: '/home/.config/opencode/skills/legion', hash: 'h'),
        },
        onDisk: {
          '/home/.claude/skills/legion': 'h',
          '/home/.config/opencode/skills/legion': 'h',
        },
        found: [
          at('/home/.claude/skills/legion', 'legion',
              [('claude', Scope.global), ('opencode', Scope.global)]),
          at('/home/.config/opencode/skills/legion', 'legion',
              [('opencode', Scope.global)]),
        ],
      );
      final dup = d.duplicates.single;
      expect(dup.host, 'opencode');
      expect(dup.isExpected, isTrue,
          reason: 'both paths are ledgered under different hosts');
      expect(d.actionableDuplicates, isEmpty);
    });

    test('an unmanaged second copy IS actionable', () {
      // Nobody chose this arrangement, so somebody can undo it.
      final d = run(
        rows: {
          unit('legion', host: 'opencode'):
              row(destination: '/home/.config/opencode/skills/legion', hash: 'h'),
        },
        onDisk: {'/home/.config/opencode/skills/legion': 'h'},
        found: [
          at('/home/.config/opencode/skills/legion', 'legion', [('opencode', Scope.global)]),
          at('/home/.config/opencode/skill/legion', 'legion', [('opencode', Scope.global)]),
        ],
      );
      expect(d.actionableDuplicates, hasLength(1));
      expect(d.actionableDuplicates.single.isExpected, isFalse);
    });

    test('duplicates come out in a stable order', () {
      final d = run(
        found: [
          at('/b/z', 'z', [('opencode', Scope.global)]),
          at('/a/z', 'z', [('opencode', Scope.global)]),
          at('/b/a', 'a', [('opencode', Scope.global)]),
          at('/a/a', 'a', [('opencode', Scope.global)]),
        ],
      );
      expect(d.duplicates.map((x) => x.artifact), ['a', 'z']);
      expect(d.duplicates.first.paths, ['/a/a', '/b/a']);
    });
  });

  group('the overall verdict', () {
    test('a clean machine has nothing to report', () {
      final d = run(
        rows: {unit('legion'): row(destination: '/d/legion', hash: 'h')},
        onDisk: {'/d/legion': 'h'},
        found: [
          FoundArtifact(
            path: '/d/legion',
            name: 'legion',
            declaredOrigin: null,
            readBy: const [('claude', Scope.global)],
          ),
        ],
      );
      expect(d.isHealthy, isTrue);
    });

    test('drift makes it unhealthy', () {
      final d = run(
        rows: {unit('legion'): row(destination: '/d/legion', hash: 'h')},
        onDisk: {'/d/legion': 'x'},
      );
      expect(d.isHealthy, isFalse);
    });

    test('a missing artifact makes it unhealthy', () {
      final d = run(
        rows: {unit('legion'): row(destination: '/d/legion', hash: 'h')},
        onDisk: {'/d/legion': null},
      );
      expect(d.isHealthy, isFalse);
    });

    test('an actionable duplicate makes it unhealthy', () {
      final d = run(
        found: [
          FoundArtifact(path: '/a/x', name: 'x', declaredOrigin: null,
              readBy: const [('opencode', Scope.global)]),
          FoundArtifact(path: '/b/x', name: 'x', declaredOrigin: null,
              readBy: const [('opencode', Scope.global)]),
        ],
      );
      expect(d.isHealthy, isFalse);
    });

    test('an unmanaged occupant does NOT', () {
      // Five macss skills beside ours is a perfectly ordinary machine. Telling
      // a user their machine is unhealthy because another tool also uses it
      // would train them to ignore the word.
      final d = run(
        found: [
          FoundArtifact(path: '/d/macss-plan', name: 'macss-plan',
              declaredOrigin: 'macss', readBy: const [('claude', Scope.global)]),
        ],
      );
      expect(d.unmanaged, hasLength(1));
      expect(d.isHealthy, isTrue);
    });

    test('another consumer owning something does NOT', () {
      final d = run(
        rows: {
          unit('macss-plan'):
              row(destination: '/d/m', hash: 'h', owner: 'macss'),
        },
        onDisk: {'/d/m': 'h'},
      );
      expect(d.isHealthy, isTrue);
    });
  });
}
