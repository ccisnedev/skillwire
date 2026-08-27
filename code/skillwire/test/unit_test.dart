import 'package:skillwire/skillwire.dart';
import 'package:test/test.dart';

/// PRD 10.1 — one unit per tuple `(artifact, kind, host, scope, subagent?)`.
///
/// R15.1 requires `kind` and `subagent` to be present from P1 even though only
/// `skill` is implemented, because adding either later would change the ledger
/// key, the reconciliation signature and the manifest schema at once.
void main() {
  Unit unit({
    String artifact = 'legion',
    Kind kind = Kind.skill,
    String host = 'claude',
    Scope scope = Scope.global,
    String? subagent,
  }) => Unit(
    artifact: artifact,
    kind: kind,
    host: host,
    scope: scope,
    subagent: subagent,
  );

  group('R15.1 the tuple is complete from P1', () {
    test('carries kind and subagent', () {
      final u = unit(kind: Kind.subagent, subagent: 'reviewer');
      expect(u.kind, Kind.subagent);
      expect(u.subagent, 'reviewer');
    });

    test('subagent is optional and defaults to null', () {
      expect(unit().subagent, isNull);
    });

    test('Kind names both members, only one of which is implemented', () {
      expect(Kind.values, [Kind.skill, Kind.subagent]);
    });

    test('Scope names exactly global and repo', () {
      expect(Scope.values, [Scope.global, Scope.repo]);
    });
  });

  group('R11.2 the key is the full tuple', () {
    test('two units differing only in kind do not collide', () {
      expect(unit(kind: Kind.skill).key, isNot(unit(kind: Kind.subagent).key));
    });

    test('two units differing only in scope do not collide', () {
      expect(unit(scope: Scope.global).key, isNot(unit(scope: Scope.repo).key));
    });

    test('two units differing only in subagent do not collide', () {
      expect(unit().key, isNot(unit(subagent: 'reviewer').key));
    });

    test('two units differing only in host do not collide', () {
      expect(unit(host: 'claude').key, isNot(unit(host: 'codex').key));
    });

    test('two units differing only in artifact do not collide', () {
      expect(unit(artifact: 'legion').key, isNot(unit(artifact: 'kritik').key));
    });

    test('the key round-trips', () {
      for (final u in [unit(), unit(kind: Kind.subagent, subagent: 'r')]) {
        expect(Unit.parse(u.key), u);
      }
    });

    test('the key is stable across constructions', () {
      expect(unit().key, unit().key);
    });
  });

  group('value equality', () {
    test('equal tuples are equal and hash alike', () {
      expect(unit(), unit());
      expect(unit().hashCode, unit().hashCode);
    });

    test('a Map keyed by Unit finds an equal Unit', () {
      expect({unit(): 1}[unit()], 1);
    });

    test('differing tuples are unequal', () {
      expect(unit(), isNot(unit(host: 'codex')));
    });
  });
}
