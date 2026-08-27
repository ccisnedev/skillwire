import 'dart:convert';
import 'dart:typed_data';

import 'package:skillwire/skillwire.dart';
import 'package:test/test.dart';

/// PRD 10.2, every row, as a pure function of (observed, desired).
///
/// **This file must never import `dart:io`.** R10.4 puts filesystem access at
/// the edges precisely so that the layer where a bug destroys a user's work is
/// testable without one. `purity_test.dart` enforces the ban.
void main() {
  Map<String, Uint8List> tree(String body) => {
    'SKILL.md': Uint8List.fromList(utf8.encode(body)),
  };

  const acting = 'skillwire_cli';
  const other = 'macss';

  final wanted = tree('desired');
  final wantedHash = contentHash(wanted);
  final differentHash = contentHash(tree('something else'));

  const u = Unit(
    artifact: 'legion',
    kind: Kind.skill,
    host: 'claude',
    scope: Scope.global,
  );

  final desired = {
    u: Desired(tree: wanted, destination: '/home/x/.claude/skills/legion'),
  };

  Plan deploy(Observed observed, {bool force = false}) => reconcile(
    operation: Operation.deploy,
    observed: {u: observed},
    desired: desired,
    actingConsumer: acting,
    force: force,
  );

  Plan remove(Observed observed, {bool force = false}) => reconcile(
    operation: Operation.remove,
    observed: {u: observed},
    desired: desired,
    actingConsumer: acting,
    force: force,
  );

  String verbOf(Plan p) => p.steps.single.preview().verb;

  // ---------------------------------------------------------------- state 1

  group('state 1 - nothing at the destination', () {
    test('plans create', () {
      expect(verbOf(deploy(const Observed())), Verb.create);
    });

    test('the preview names the destination, not the artifact', () {
      // The same artifact is deployed to several hosts in one run; a plan whose
      // lines cannot be told apart is not a plan.
      expect(
        deploy(const Observed()).steps.single.preview().target,
        '/home/x/.claude/skills/legion',
      );
    });

    test('a ledger row with nothing on disk is still create', () {
      // The ledger claims we deployed it; the world says otherwise. Recreating
      // is right, and destroys nothing.
      expect(
        verbOf(
          deploy(
            Observed(
              ledger: LedgerRecord(owner: acting, contentHash: wantedHash),
            ),
          ),
        ),
        Verb.create,
      );
    });
  });

  // ---------------------------------------------------------------- state 2

  group('state 2 - ours, hash matches', () {
    final observed = Observed(
      contentHash: wantedHash,
      ledger: LedgerRecord(owner: acting, contentHash: wantedHash),
    );

    test('plans keep', () => expect(verbOf(deploy(observed)), Verb.keep));

    test('keep is not applicable work', () {
      expect(deploy(observed).hasWork, isFalse);
    });
  });

  // ---------------------------------------------------------------- state 3

  group('state 3 - ours, hash differs from desired', () {
    final observed = Observed(
      contentHash: differentHash,
      ledger: LedgerRecord(owner: acting, contentHash: differentHash),
    );

    test('plans replace', () => expect(verbOf(deploy(observed)), Verb.replace));

    test('the detail shows old to new', () {
      final detail = deploy(observed).steps.single.preview().detail!;
      expect(detail, contains(differentHash.substring(0, 8)));
      expect(detail, contains(wantedHash.substring(0, 8)));
    });
  });

  // ---------------------------------------------------------------- state 4

  group('state 4 - ours, but modified at the destination', () {
    // The ledger records what we wrote; the disk holds something else. Someone
    // edited it, and deploying would lose their work.
    final observed = Observed(
      contentHash: differentHash,
      ledger: LedgerRecord(owner: acting, contentHash: wantedHash),
    );

    test('plans block', () => expect(verbOf(deploy(observed)), Verb.block));

    test('--force does not lift it', () {
      expect(verbOf(deploy(observed, force: true)), Verb.block);
    });

    test('the detail says the destination was modified', () {
      expect(
        deploy(observed).steps.single.preview().detail,
        contains('modified'),
      );
    });

    test('remove DOES act on it - R10.3 names states 2, 3 and 4', () {
      expect(verbOf(remove(observed)), Verb.remove);
    });

    test('drift is state 4 even when the disk happens to match desired', () {
      // Ledger says A, disk says B, desired is B. Nothing would be lost by
      // deploying, but the ledger disagrees with the world, and that is drift
      // the user is entitled to see rather than have quietly reconciled.
      expect(
        verbOf(
          deploy(
            Observed(
              contentHash: wantedHash,
              ledger: LedgerRecord(owner: acting, contentHash: differentHash),
            ),
          ),
        ),
        Verb.block,
      );
    });
  });

  // ---------------------------------------------------------------- state 5

  group('state 5 - deployed by a different consumer', () {
    final observed = Observed(
      contentHash: wantedHash,
      ledger: LedgerRecord(owner: other, contentHash: wantedHash),
    );

    test('plans block', () => expect(verbOf(deploy(observed)), Verb.block));

    test('the plan names the owning consumer', () {
      expect(deploy(observed).steps.single.preview().detail, contains(other));
    });

    test('--force does not lift it, even with an identical hash', () {
      // Rule 1: never destroy what the acting consumer did not deploy. An equal
      // hash is not ownership.
      expect(verbOf(deploy(observed, force: true)), Verb.block);
    });

    test('remove never acts on it, with or without --force (R10.3)', () {
      expect(verbOf(remove(observed)), Verb.block);
      expect(verbOf(remove(observed, force: true)), Verb.block);
    });
  });

  // ---------------------------------------------------------------- state 6

  group('state 6 - present but absent from the ledger', () {
    final matching = Observed(contentHash: wantedHash);
    final differing = Observed(contentHash: differentHash);

    test('plans block without --force', () {
      expect(verbOf(deploy(matching)), Verb.block);
    });

    test('the detail names no consumer, because there is none to name', () {
      final detail = deploy(matching).steps.single.preview().detail!;
      expect(detail, isNot(contains(other)));
      expect(detail, contains('no consumer'));
    });

    test('R10.6 - --force adopts when the hash matches', () {
      expect(verbOf(deploy(matching, force: true)), Verb.adopt);
    });

    test('R10.6 - adoption writes nothing to the destination', () {
      // A ledger-only operation. A test checking only the verb would pass for
      // an implementation that rewrote identical bytes and called it adopt.
      final step = deploy(matching, force: true).steps.single as ReconcileStep;
      expect(step.writesDestination, isFalse);
    });

    test('R10.6 - a differing hash stays blocked under --force', () {
      // This is what protects a skill the user wrote by hand under a name the
      // package also ships.
      expect(verbOf(deploy(differing, force: true)), Verb.block);
    });

    test('remove never acts on it, with or without --force (R10.3)', () {
      expect(verbOf(remove(matching)), Verb.block);
      expect(verbOf(remove(matching, force: true)), Verb.block);
    });
  });

  // ------------------------------------------------------------------ remove

  group('remove', () {
    test('nothing at the destination is absent, not an error', () {
      expect(verbOf(remove(const Observed())), Verb.absent);
    });

    test('ours and unchanged is removed', () {
      expect(
        verbOf(
          remove(
            Observed(
              contentHash: wantedHash,
              ledger: LedgerRecord(owner: acting, contentHash: wantedHash),
            ),
          ),
        ),
        Verb.remove,
      );
    });
  });

  // ------------------------------------------------------- R10.1/R10.2/R10.5

  group('R10.1 and R10.2 - what --force does and does not do', () {
    final blocked = Observed(
      contentHash: wantedHash,
      ledger: LedgerRecord(owner: other, contentHash: wantedHash),
    );

    test('a plan containing any block is not applicable without --force', () {
      expect(deploy(blocked).isApplicable, isFalse);
    });

    test('--force makes it applicable', () {
      expect(deploy(blocked, force: true).isApplicable, isTrue);
    });

    test('a plan with no block is applicable without --force', () {
      expect(deploy(const Observed()).isApplicable, isTrue);
    });

    test('--force never turns a blocked unit into work', () {
      // It lifts the refusal of the plan, not the block on the unit.
      final plan = deploy(blocked, force: true);
      expect(plan.isApplicable, isTrue);
      expect(plan.steps.single.preview().verb, Verb.block);
    });

    test('blocks are reported as a list a caller can act on', () {
      expect(deploy(blocked).blocked, hasLength(1));
      expect(deploy(blocked).blocked.single.unit, u);
    });
  });

  group('R10.5 - idempotence', () {
    test('what create leaves behind plans as keep on the second run', () {
      expect(verbOf(deploy(const Observed())), Verb.create);

      // The world after a successful apply: the tree is on disk and the ledger
      // records it.
      final second = deploy(
        Observed(
          contentHash: wantedHash,
          ledger: LedgerRecord(owner: acting, contentHash: wantedHash),
        ),
      );
      expect(second.steps.single.preview().verb, Verb.keep);
      expect(second.hasWork, isFalse);
    });

    test('what adopt leaves behind also plans as keep', () {
      expect(verbOf(deploy(Observed(contentHash: wantedHash), force: true)),
          Verb.adopt);

      final second = deploy(
        Observed(
          contentHash: wantedHash,
          ledger: LedgerRecord(owner: acting, contentHash: wantedHash),
        ),
      );
      expect(second.steps.single.preview().verb, Verb.keep);
    });
  });

  group('plan shape', () {
    test('steps come out in a stable order', () {
      final units = ['research', 'kritik', 'legion'].map(
        (a) => Unit(
          artifact: a,
          kind: Kind.skill,
          host: 'claude',
          scope: Scope.global,
        ),
      );
      final plan = reconcile(
        operation: Operation.deploy,
        observed: {for (final x in units) x: const Observed()},
        desired: {
          for (final x in units)
            x: Desired(tree: wanted, destination: '/d/${x.artifact}'),
        },
        actingConsumer: acting,
      );
      expect(plan.steps.map((s) => s.preview().target), [
        '/d/kritik',
        '/d/legion',
        '/d/research',
      ]);
    });

    test('a unit desired but never observed is treated as absent', () {
      final plan = reconcile(
        operation: Operation.deploy,
        observed: const {},
        desired: desired,
        actingConsumer: acting,
      );
      expect(plan.steps.single.preview().verb, Verb.create);
    });
  });
}
