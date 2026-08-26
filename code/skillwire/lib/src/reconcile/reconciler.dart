import 'package:preview_executor/preview_executor.dart';

import '../domain/unit.dart';
import 'state.dart';
import 'steps.dart';

/// An ordered list of steps, and what a caller needs to know before applying it.
///
/// Not "a plan type of this package's own" in the sense R12.6 forbids: the plan
/// **is** [steps], and the SDK renders and approves that list. The rest is the
/// two questions a caller must answer before running it — may I apply, and is
/// there anything to do.
class Plan {
  Plan({required this.steps, required this.force});

  /// The plan itself, in the order it will run.
  final List<Step> steps;

  /// Whether `--force` was passed. R10.2: no other flag implies it.
  final bool force;

  /// Units this run must not disturb (PRD 10.2 states 4, 5, 6).
  List<BlockedUnit> get blocked => steps.whereType<BlockedUnit>().toList();

  /// R10.1 — a plan containing any `block` refuses `--apply` unless `--force`.
  ///
  /// Note what `--force` does here and what it does not. It lifts the refusal
  /// of the **plan**, letting the applicable units through; it never lifts the
  /// block on a **unit**. A blocked unit stays blocked and performs nothing.
  bool get isApplicable => force || blocked.isEmpty;

  /// Whether anything would change. A plan of nothing but `keep` and `absent`
  /// is a plan the SDK can report as nothing-to-do.
  bool get hasWork =>
      steps.whereType<ReconcileStep>().any((s) => s.verb != Verb.keep && s.verb != Verb.absent);
}

/// Sink used when a plan is built for inspection rather than for applying.
///
/// `skill list`, `skill doctor` and every `--plan` run build steps only to read
/// their previews. Handing them a sink that throws makes "this was never meant
/// to run" a crash rather than a silent write.
class _InertSink implements DeploymentSink {
  const _InertSink();

  Never _refuse() => throw StateError(
    'This plan was built for inspection and has no sink. Rebuild it with a '
    'real DeploymentSink before performing any step.',
  );

  @override
  Future<void> writeTree(String d, Map<String, dynamic> t) => _refuse();

  @override
  Future<void> deleteTree(String d) => _refuse();

  @override
  Future<void> record(Unit u, String h) => _refuse();

  @override
  Future<void> forget(Unit u) => _refuse();
}

/// Make a host's directories match a desired set of materialised artifacts.
///
/// **Pure.** A function of two values and nothing else: no filesystem, no clock,
/// no environment (R10.4). I/O lives at the edges — one read before to build
/// [observed], one write after when the steps are performed. That is deliberate,
/// because this is the layer where a bug destroys a user's work, and it is the
/// only way every row of PRD 10.2 is testable without a disk.
///
/// It does not know, and must not know, how any artifact was materialised
/// (R8.1). A static skill, a generated one and a transformed subagent reach it
/// in the same shape, which is what lets one engine serve all three.
Plan reconcile({
  required Operation operation,
  required Map<Unit, Observed> observed,
  required Map<Unit, Desired> desired,
  required String actingConsumer,
  bool force = false,
  Map<Unit, List<String>> annotations = const {},
  DeploymentSink sink = const _InertSink(),
}) {
  // Sorted so a plan reads the same twice and a diff of two plans is legible.
  final units = desired.keys.toList()..sort((a, b) => a.key.compareTo(b.key));

  return Plan(
    force: force,
    steps: [
      for (final unit in units)
        _step(
          operation: operation,
          unit: unit,
          observed: observed[unit] ?? const Observed(),
          desired: desired[unit]!,
          actingConsumer: actingConsumer,
          force: force,
          annotations: annotations[unit] ?? const [],
          sink: sink,
        ),
    ],
  );
}

ReconcileStep _step({
  required Operation operation,
  required Unit unit,
  required Observed observed,
  required Desired desired,
  required String actingConsumer,
  required bool force,
  required List<String> annotations,
  required DeploymentSink sink,
}) {
  final destination = desired.destination;
  final ledger = observed.ledger;

  BlockedUnit block(String reason) => BlockedUnit(
    unit: unit,
    destination: destination,
    reason: reason,
    annotations: annotations,
  );

  // ---- State 1: nothing at the destination. -------------------------------
  //
  // Checked before the ledger, because a ledger row for a directory that is no
  // longer there describes a world that has moved on. Recreating it is right,
  // and destroys nothing.
  if (!observed.isPresent) {
    return operation == Operation.deploy
        ? ApplyUnit(
            unit: unit,
            destination: destination,
            verb: Verb.create,
            tree: desired.tree,
            contentHash: desired.contentHash,
            sink: sink,
            annotations: annotations,
          )
        : RetireUnit(
            unit: unit,
            destination: destination,
            verb: Verb.absent,
            sink: sink,
            annotations: annotations,
          );
  }

  // ---- State 6: present, but no consumer recorded it. ---------------------
  if (ledger == null) {
    if (operation == Operation.deploy &&
        force &&
        observed.contentHash == desired.contentHash) {
      // R10.6 — adoption. The ledger gains a row naming the acting consumer and
      // the destination is not touched. This is how a machine carrying
      // pre-package deployments migrates without a byte being destroyed.
      return ApplyUnit(
        unit: unit,
        destination: destination,
        verb: Verb.adopt,
        tree: desired.tree,
        contentHash: desired.contentHash,
        sink: sink,
        reason: 'adopted into the ledger; contents already identical, nothing written',
        annotations: annotations,
      );
    }
    return block(
      observed.contentHash == desired.contentHash
          ? 'present but no consumer deployed it; --force would adopt it '
                '(contents already identical)'
          : 'present but no consumer deployed it, and its contents differ from '
                'what would be deployed; --force will not adopt it',
    );
  }

  // ---- State 5: someone else's. -------------------------------------------
  //
  // Before the drift check, because whose it is matters more than what state it
  // is in. R10.3 keeps removal off it with or without --force, and rule 1 keeps
  // deployment off it for the same reason.
  if (ledger.owner != actingConsumer) {
    return block('deployed by ${ledger.owner}; $actingConsumer will not disturb it');
  }

  // ---- State 4: ours, but changed underneath us. --------------------------
  //
  // The ledger records what we wrote and the disk holds something else. We do
  // not know what those edits were worth, so we do not overwrite them — even
  // when the disk happens to match what we would deploy, because the ledger
  // disagreeing with the world is drift the user is entitled to see.
  if (ledger.contentHash != observed.contentHash) {
    if (operation == Operation.remove) {
      // R10.3 names states 2, 3 and 4 as removable. Removal is the one
      // operation the user has explicitly asked for on their own artifact.
      return RetireUnit(
        unit: unit,
        destination: destination,
        verb: Verb.remove,
        sink: sink,
        reason: 'modified at the destination since it was deployed',
        annotations: annotations,
      );
    }
    return block(
      'modified at the destination since $actingConsumer deployed it; '
      'local edits would be lost',
    );
  }

  // ---- States 2 and 3: ours and intact. -----------------------------------
  if (operation == Operation.remove) {
    return RetireUnit(
      unit: unit,
      destination: destination,
      verb: Verb.remove,
      sink: sink,
      annotations: annotations,
    );
  }

  final matches = observed.contentHash == desired.contentHash;
  return ApplyUnit(
    unit: unit,
    destination: destination,
    verb: matches ? Verb.keep : Verb.replace,
    tree: desired.tree,
    contentHash: desired.contentHash,
    sink: sink,
    reason: matches
        ? null
        : '${_short(observed.contentHash!)} -> ${_short(desired.contentHash)}',
    annotations: annotations,
  );
}

String _short(String hash) => hash.substring(0, 8);
