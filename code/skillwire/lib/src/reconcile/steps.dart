import 'dart:typed_data';

import 'package:preview_executor/preview_executor.dart';

import '../domain/unit.dart';
import 'state.dart';

/// Where a step's effects go.
///
/// The one seam between a decided plan and the world. Reconciliation decides
/// with no I/O (R10.4); the writing happens here, behind an interface, so
/// `perform()` is testable without a disk and the real implementation is the
/// only thing that touches one.
abstract interface class DeploymentSink {
  /// Replace whatever is at [destination] with [tree]. Creates parents.
  Future<void> writeTree(String destination, Map<String, Uint8List> tree);

  /// Remove [destination] and everything under it.
  Future<void> deleteTree(String destination);

  /// Record [unit] in the ledger as owned by the acting consumer, holding
  /// [contentHash].
  Future<void> record(Unit unit, String contentHash);

  /// Drop [unit] from the ledger.
  Future<void> forget(Unit unit);
}

/// One unit of PRD 10.1, with its verb already decided.
///
/// `preview()` reports a decision the constructor settled rather than deciding
/// again. `preview_executor` makes the point in its own documentation: a step
/// that recomputes what its constructor already resolved is how a preview comes
/// to describe a different change from the one that happens.
sealed class ReconcileStep implements Step {
  ReconcileStep({
    required this.unit,
    required this.destination,
    required this.verb,
    this.reason,
    this.annotations = const [],
  });

  final Unit unit;
  final String destination;

  /// This unit's decided verb (see [Verb]). Not part of the `Step` interface,
  /// which declares only `preview()` and `perform()`; it is carried here so a
  /// caller can group a plan by outcome without re-previewing every step.
  final String verb;

  /// Why this verb, when the verb alone does not say. Blocks always carry one.
  final String? reason;

  /// Non-blocking consequences of this unit that the user cannot infer
  /// (PRD 7.5). They never change [verb] and never refuse an apply (R7.7).
  final List<String> annotations;

  /// Whether performing this step writes to [destination].
  ///
  /// Load-bearing for R10.6: adoption is a ledger-only operation, and a test
  /// that checked only the verb would pass for an implementation that rewrote
  /// identical bytes and reported `adopt`.
  bool get writesDestination;

  @override
  Preview preview() => Preview(verb: verb, target: destination, detail: _detail);

  String? get _detail {
    final parts = [?reason, ...annotations];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

/// A unit that is deployed, adopted, or already correct.
class ApplyUnit extends ReconcileStep {
  ApplyUnit({
    required super.unit,
    required super.destination,
    required super.verb,
    required this.tree,
    required this.contentHash,
    required this.sink,
    super.reason,
    super.annotations,
  });

  /// The bytes to write. Resolved when the step was built, not again.
  final Map<String, Uint8List> tree;

  /// The hash of [tree], recorded in the ledger on success.
  final String contentHash;

  final DeploymentSink sink;

  /// `keep` has nothing to do and `adopt` touches only the ledger (R10.6).
  @override
  bool get writesDestination => verb == Verb.create || verb == Verb.replace;

  @override
  Future<Outcome> perform(StepContext context) async {
    // `keep` is state 2: the destination holds what we recorded and what we
    // want. Nothing is written and no timestamp advances (R11.3).
    if (verb == Verb.keep) {
      return Outcome(verb: verb, target: destination, detail: _detail);
    }
    if (writesDestination) {
      await sink.writeTree(destination, tree);
    }
    await sink.record(unit, contentHash);
    return Outcome(verb: verb, target: destination, detail: _detail);
  }
}

/// A unit being taken back out.
class RetireUnit extends ReconcileStep {
  RetireUnit({
    required super.unit,
    required super.destination,
    required super.verb,
    required this.sink,
    super.reason,
    super.annotations,
  });

  final DeploymentSink sink;

  @override
  bool get writesDestination => verb == Verb.remove;

  @override
  Future<Outcome> perform(StepContext context) async {
    if (verb == Verb.remove) {
      await sink.deleteTree(destination);
      await sink.forget(unit);
    }
    return Outcome(verb: verb, target: destination, detail: _detail);
  }
}

/// A unit this run must not disturb: PRD 10.2 states 4, 5 and 6.
///
/// It is a step rather than an omission so that it appears in the plan. A unit
/// silently dropped is a unit the user believes was handled.
class BlockedUnit extends ReconcileStep {
  BlockedUnit({
    required super.unit,
    required super.destination,
    required String super.reason,
    super.annotations,
  }) : super(verb: Verb.block);

  @override
  bool get writesDestination => false;

  @override
  Future<Outcome> perform(StepContext context) async =>
      Outcome(verb: Verb.block, target: destination, detail: _detail);
}
