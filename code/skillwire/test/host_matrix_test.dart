import 'package:skillwire/skillwire.dart';
import 'package:test/test.dart';

/// PRD 6 — the matrix, and the rules that keep it honest.
void main() {
  final matrix = HostMatrix.builtIn();

  group('R6.3 - the matrix is data, so adding a host is a data change', () {
    test('a host that exists only in a fabricated document resolves', () {
      // The real test of R6.3. If accepting a new host needed a Dart edit, the
      // matrix would be code wearing a data costume.
      final fabricated = HostMatrix.parse('''
version: 1
hosts:
  borg:
    name: Borg Code
    marker: "~/.borg"
    skills:
      global:
        - path: "~/.borg/skills"
          provenance: {source: "fabricated for this test", read: "2026-08-26"}
''');
      expect(fabricated.hostIds, ['borg']);
      expect(fabricated.destination('borg', Scope.global).template, '~/.borg/skills');
    });

    test('an unknown host is a typed error, not a null', () {
      expect(() => matrix.host('borg'), throwsA(isA<UnknownHost>()));
    });
  });

  group('the five hosts', () {
    test('all five are present', () {
      expect(matrix.hostIds,
          ['antigravity', 'claude', 'codex', 'copilot', 'opencode']);
    });

    test('each has a global and a repo destination', () {
      for (final id in matrix.hostIds) {
        for (final scope in Scope.values) {
          expect(() => matrix.destination(id, scope), returnsNormally,
              reason: '$id at ${scope.token}');
        }
      }
    });
  });

  group('R6.4 and R14.2 - every path carries provenance', () {
    test('no directory in the matrix is unverified', () {
      for (final id in matrix.hostIds) {
        for (final scope in Scope.values) {
          for (final d in matrix.host(id).skills[scope]!) {
            expect(d.provenance.isVerified, isTrue,
                reason: '$id ${scope.token} ${d.template}');
          }
        }
      }
    });

    test('every provenance names a source and a date', () {
      for (final id in matrix.hostIds) {
        for (final d in matrix.host(id).skills[Scope.global]!) {
          expect(d.provenance.source, isNotEmpty);
          expect(d.provenance.read, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')),
              reason: '$id ${d.template} has no ISO date');
        }
      }
    });

    test('an unverified row refuses to resolve rather than guessing', () {
      final unsourced = HostMatrix.parse('''
version: 1
hosts:
  ghost:
    name: Ghost
    marker: "~/.ghost"
    skills:
      global:
        - path: "~/.ghost/skills"
''');
      expect(
        () => unsourced.destination('ghost', Scope.global),
        throwsA(isA<UnverifiedHostPath>()),
      );
    });

    test('a host with no directory at a scope also refuses', () {
      final partial = HostMatrix.parse('''
version: 1
hosts:
  half:
    name: Half
    marker: "~/.half"
    skills:
      global:
        - path: "~/.half/skills"
          provenance: {source: "test", read: "2026-08-26"}
''');
      expect(
        () => partial.destination('half', Scope.repo),
        throwsA(isA<UnverifiedHostPath>()),
      );
    });
  });

  group('R6.1 - Codex resolves CODEX_HOME with a fallback', () {
    test('the global destination is the environment variable form', () {
      final d = matrix.destination('codex', Scope.global);
      expect(d.template, r'$CODEX_HOME/skills');
      expect(d.fallback, '~/.codex/skills');
    });

    test('hardcoding ~/.codex as the primary would be non-conforming', () {
      expect(matrix.destination('codex', Scope.global).template,
          isNot('~/.codex/skills'));
    });
  });

  group('R6.2 and R6.5 - one destination, several observed spellings', () {
    test('OpenCode writes the plural and observes both', () {
      expect(matrix.destination('opencode', Scope.global).template,
          '~/.config/opencode/skills');
      expect(matrix.observed('opencode', Scope.global),
          contains('~/.config/opencode/skill'));
    });

    test('Antigravity writes .agents and observes all four spellings', () {
      expect(matrix.destination('antigravity', Scope.repo).template, '.agents/skills');
      final observed = matrix.observed('antigravity', Scope.repo);
      for (final alias in ['.agent/skills', '_agents/skills', '_agent/skills']) {
        expect(observed, contains(alias));
      }
    });

    test('observed is a superset of the destination for every host', () {
      for (final id in matrix.hostIds) {
        for (final scope in Scope.values) {
          expect(matrix.observed(id, scope),
              contains(matrix.destination(id, scope).template));
        }
      }
    });
  });

  group('PRD 7.1 - the visibility graph', () {
    Set<String> allFive() => matrix.hostIds.toSet();

    test('R7.1 - Copilot reads Claude at repo scope only', () {
      expect(
        matrix.alsoRead(
          directory: '.claude/skills',
          scope: Scope.repo,
          excluding: 'claude',
          detected: allFive(),
        ).map((e) => e.host),
        contains('copilot'),
      );
    });

    test('R7.1 - and NOT at global scope', () {
      // GitHub lists ~/.copilot/skills and ~/.agents/skills as the personal
      // locations; ~/.claude/skills is not among them. A global edge here would
      // produce a warning that is simply false.
      expect(
        matrix.alsoRead(
          directory: '~/.claude/skills',
          scope: Scope.global,
          excluding: 'claude',
          detected: allFive(),
        ).map((e) => e.host),
        isNot(contains('copilot')),
      );
    });

    test('OpenCode reads Claude at both scopes', () {
      for (final (dir, scope) in [
        ('~/.claude/skills', Scope.global),
        ('.claude/skills', Scope.repo),
      ]) {
        expect(
          matrix.alsoRead(
            directory: dir,
            scope: scope,
            excluding: 'claude',
            detected: allFive(),
          ).map((e) => e.host),
          contains('opencode'),
          reason: '$dir at ${scope.token}',
        );
      }
    });

    test('the neutral namespace reaches four hosts at repo scope', () {
      expect(
        matrix.alsoRead(
          directory: '.agents/skills',
          scope: Scope.repo,
          excluding: 'nobody',
          detected: allFive(),
        ).map((e) => e.host).toSet(),
        {'codex', 'opencode', 'copilot', 'antigravity'},
      );
    });

    test('R7.4 - an undetected host is never named', () {
      expect(
        matrix.alsoRead(
          directory: '.agents/skills',
          scope: Scope.repo,
          excluding: 'nobody',
          detected: {'codex'},
        ).map((e) => e.host),
        ['codex'],
      );
    });

    test('the targeted host is never reported as also reading', () {
      expect(
        matrix.alsoRead(
          directory: '.agents/skills',
          scope: Scope.repo,
          excluding: 'codex',
          detected: allFive(),
        ).map((e) => e.host),
        isNot(contains('codex')),
      );
    });

    test('every edge names a source', () {
      for (final e in matrix.visibility) {
        expect(e.source, isNotEmpty, reason: '${e.host} <- ${e.reads}');
      }
    });
  });

  group('R6.11 - reserved names', () {
    test('synced is reserved', () {
      expect(matrix.reservedReason('synced'), isNotNull);
    });

    test('in any capitalisation', () {
      for (final n in ['SYNCED', 'Synced', 'sYnCeD']) {
        expect(matrix.reservedReason(n), isNotNull, reason: n);
      }
    });

    test('an ordinary name is not reserved', () {
      expect(matrix.reservedReason('legion'), isNull);
    });
  });

  group('R6.10 - never destinations', () {
    test('/etc/codex/skills is one, with a stated reason', () {
      expect(matrix.neverDestinations, contains('/etc/codex/skills'));
      expect(matrix.neverDestinations['/etc/codex/skills'], isNotEmpty);
    });

    test('no host names it as a destination', () {
      for (final id in matrix.hostIds) {
        for (final scope in Scope.values) {
          expect(matrix.observed(id, scope), isNot(contains('/etc/codex/skills')));
        }
      }
    });
  });
}
