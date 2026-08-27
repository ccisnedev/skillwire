import 'package:skillwire/skillwire.dart';
import 'package:test/test.dart';

/// R12.7 — a typed hierarchy rooted in a single sealed type. Every condition a
/// caller must distinguish gets its own type, so no consumer ever matches on
/// message text to decide what happened.
void main() {
  final all = <SkillwireError>[
    const UnknownHost('borg'),
    const UnverifiedHostPath(host: 'antigravity', scope: Scope.global),
    const NotADestination(path: '/etc/codex/skills', reason: 'machine-wide (R6.10)'),
    const MissingParameter('--scope'),
    const RepoScopeOutsideRepository('C:/tmp'),
    const LedgerUnreadable(path: '~/.skillwire/ledger.json', cause: 'invalid JSON'),
    const SkillInvalid(artifact: 'legion', findings: ['name must match directory']),
  ];

  group('the hierarchy', () {
    test('every error is a SkillwireError and an Exception', () {
      for (final e in all) {
        expect(e, isA<SkillwireError>());
        expect(e, isA<Exception>());
      }
    });

    test('every error carries a non-empty message', () {
      for (final e in all) {
        expect(e.message, isNotEmpty, reason: '${e.runtimeType} has no message');
      }
    });

    test('every code is stable, snake_case and unique', () {
      final codes = all.map((e) => e.code).toList();
      expect(codes.toSet().length, codes.length, reason: 'codes collide: $codes');
      for (final c in codes) {
        expect(c, matches(RegExp(r'^[a-z][a-z0-9_]*$')), reason: c);
      }
    });

    test('toString names the code, so a stack trace is legible', () {
      expect(const UnknownHost('borg').toString(), contains('unknown_host'));
    });
  });

  group('a consumer distinguishes by type, never by message', () {
    // The point of R12.7: this switch is exhaustive, and the analyser proves
    // it. A new error type breaks every consumer at compile time rather than
    // falling through a string match at runtime.
    String exitReason(SkillwireError e) => switch (e) {
      UnknownHost() => 'usage',
      MissingParameter() => 'usage',
      RepoScopeOutsideRepository() => 'usage',
      UnverifiedHostPath() => 'refused',
      NotADestination() => 'refused',
      SkillInvalid() => 'invalid',
      LedgerUnreadable() => 'state',
    };

    test('each type maps to its own outcome', () {
      expect(exitReason(const UnknownHost('borg')), 'usage');
      expect(
        exitReason(const UnverifiedHostPath(host: 'antigravity', scope: Scope.repo)),
        'refused',
      );
      expect(
        exitReason(const LedgerUnreadable(path: 'p', cause: 'c')),
        'state',
      );
    });
  });

  group('errors carry their particulars, not just prose', () {
    test('UnverifiedHostPath names the host and scope it refused', () {
      const e = UnverifiedHostPath(host: 'antigravity', scope: Scope.global);
      expect(e.host, 'antigravity');
      expect(e.scope, Scope.global);
      expect(e.message, contains('antigravity'));
    });

    test('SkillInvalid reports every finding, not the first', () {
      const e = SkillInvalid(artifact: 'x', findings: ['a', 'b', 'c']);
      expect(e.findings, hasLength(3));
      expect(e.message, allOf(contains('a'), contains('b'), contains('c')));
    });

    test('MissingParameter names the parameter', () {
      expect(const MissingParameter('--host').parameter, '--host');
    });
  });
}
