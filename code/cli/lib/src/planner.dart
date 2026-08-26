import 'package:path/path.dart' as p;
import 'package:skillwire/skillwire.dart';

import 'catalogue.dart';
import 'workspace.dart';

/// The consumer that acts. Written into every ledger row this CLI creates, and
/// the only thing that makes PRD 10.2 state 5 answerable for the others.
const actingConsumer = 'skillwire_cli';

/// What a run was asked to touch.
///
/// R12.2: there is no implicit "all hosts" and no default scope. Every field
/// here arrives from an explicit flag, and omitting one is an error rather than
/// a default — which is why nothing in this class has one.
class Selection {
  const Selection({
    required this.hosts,
    required this.scope,
    required this.skills,
  });

  final List<String> hosts;
  final Scope scope;

  /// The artifacts named, already resolved from `--skill`, `--module` or
  /// `--all`.
  final List<ShippedSkill> skills;
}

/// Builds a plan from a selection, doing the one read that R10.4 allows before
/// the pure decision and none after.
class Planner {
  const Planner({required this.workspace, required this.catalogue});

  final Workspace workspace;
  final Catalogue catalogue;

  /// Every unit the selection names, with its resolved destination.
  Map<Unit, Desired> desired(Selection selection) {
    final out = <Unit, Desired>{};
    for (final host in selection.hosts) {
      final destinationDir =
          workspace.resolver.destinationFor(workspace.matrix, host, selection.scope);
      for (final skill in selection.skills) {
        out[Unit(
          artifact: skill.name,
          kind: Kind.skill,
          host: host,
          scope: selection.scope,
        )] = Desired(
          tree: skill.tree,
          destination: p.join(destinationDir, skill.name),
        );
      }
    }
    return out;
  }

  /// Read what is at each destination. The "one read before".
  Map<Unit, Observed> observe(Map<Unit, Desired> desired, Ledger ledger) => {
    for (final e in desired.entries)
      e.key: observeUnit(
        destination: e.value.destination,
        unit: e.key,
        ledger: ledger,
        hash: contentHash,
      ),
  };

  /// Plan annotations for each unit (PRD 7.5).
  ///
  /// They never change a verb and never refuse an apply (R7.7). What they do is
  /// say what the user cannot infer: that a directory they targeted is also
  /// read by a host they did not name, and that at global scope Claude Code and
  /// OpenCode cannot hold different variants of a same-named skill.
  Map<Unit, List<String>> annotations(
    Map<Unit, Desired> desired,
    Selection selection, {
    required bool removing,
  }) {
    final detected = workspace.detectedHosts;
    final out = <Unit, List<String>>{};

    for (final e in desired.entries) {
      final unit = e.key;
      final notes = <String>[];

      // R7.2 and R7.3 — the directory this lands in, read by a detected host
      // that was not named. The template is compared, not the absolute path,
      // because the graph is expressed in matrix terms.
      final template = workspace.matrix.destination(unit.host, unit.scope).template;
      final alsoRead = workspace.matrix.alsoRead(
        directory: template,
        scope: unit.scope,
        excluding: unit.host,
        detected: detected,
      );
      if (alsoRead.isNotEmpty) {
        final names =
            (alsoRead.map((v) => v.host).toSet().toList()..sort()).join(', ');
        notes.add(
          removing
              ? 'also removed from the view of: $names'
              : 'also visible from: $names',
        );
      }

      // R7.6 via R7.8 — the irreducible limitation. At global scope OpenCode
      // reads ~/.claude/skills and cannot be prevented, so the two hosts cannot
      // hold different variants of a same-named skill. At repo scope it is
      // avoidable, and saying so there would be noise.
      if (unit.scope == Scope.global &&
          unit.host == 'claude' &&
          detected.contains('opencode')) {
        notes.add(
          'OpenCode reads this directory and cannot be prevented, so the two '
          'cannot hold different variants of this skill at global scope',
        );
      }

      // R13.9 — compatibility is prose the author wrote about which product
      // they had in mind. Surfaced when the target host is not named in it,
      // never parsed into a rule.
      final skill = catalogue.byName(unit.artifact);
      final compatibility = skill?.compatibility;
      if (compatibility != null && !_mentions(compatibility, unit.host)) {
        notes.add('declares compatibility: "$compatibility"');
      }

      if (notes.isNotEmpty) out[unit] = notes;
    }
    return out;
  }

  bool _mentions(String text, String host) {
    final lower = text.toLowerCase();
    if (lower.contains(host)) return true;
    // The matrix's display name, so "Designed for Claude Code" matches `claude`.
    return lower.contains(workspace.matrix.host(host).name.toLowerCase());
  }
}

/// Alias so this file reads as prose rather than as a name collision.
final observeUnit = observe;
