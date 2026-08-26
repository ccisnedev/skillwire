import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:skillwire/skillwire.dart';

import '../../../src/catalogue.dart';
import '../../../src/planner.dart';
import '../../../src/workspace.dart';

// ─── validate ───────────────────────────────────────────────────────────────

class SkillValidateInput extends Input {
  SkillValidateInput();

  factory SkillValidateInput.fromCliRequest(CliRequest req) => SkillValidateInput();

  /// Takes nothing. Conformance is a property of what this release ships, not
  /// of where it might be deployed, so a host or a scope would be noise.
  static const List<CliParam> params = [];

  @override
  List<CliParam> get schemaFields => params;

  @override
  Map<String, dynamic> toJson() => const {};
}

class SkillValidateOutput extends Output {
  SkillValidateOutput({required this.results, required this.duplicates});

  final List<ValidationResult> results;
  final List<String> duplicates;

  bool get isClean =>
      duplicates.isEmpty && results.every((r) => r.isValid);

  @override
  Map<String, dynamic> toJson() => {
    'duplicates': duplicates,
    'skills': [
      for (final r in results)
        {
          'artifact': r.artifact,
          'valid': r.isValid,
          'findings': [for (final f in r.findings) f.toString()],
        },
    ],
  };

  @override
  int get exitCode => isClean ? ExitCode.ok : ExitCode.validationFailed;

  @override
  String? toText() {
    final lines = <String>[];
    if (duplicates.isEmpty && results.isEmpty) {
      return 'This release ships no skills.';
    }
    for (final d in duplicates) {
      lines.add('$d: appears in more than one module; deployment is flat (R13.2)');
    }
    for (final r in results) {
      if (r.isValid) {
        lines.add('${r.artifact}: ok');
      } else {
        lines.add('${r.artifact}:');
        for (final f in r.findings) {
          lines.add('  $f');
        }
      }
    }
    return lines.join('\n');
  }
}

/// `skill validate` — conformance of sources to the specification (PRD 12.2).
///
/// The gate every skill passes before it can land. It implements PRD 13.1 in
/// Dart because the reference validator is Python and self-described as for
/// demonstration, and no machine-readable schema is published.
class SkillValidateCommand
    implements Query<SkillValidateInput, SkillValidateOutput> {
  SkillValidateCommand(this.input, {required this.catalogue});

  @override
  final SkillValidateInput input;

  final Catalogue catalogue;

  @override
  String? validate() => null;

  @override
  Future<SkillValidateOutput> execute() async => SkillValidateOutput(
    results: [for (final s in catalogue.skills) s.validation],
    duplicates: catalogue.duplicateNames,
  );
}

// ─── doctor ─────────────────────────────────────────────────────────────────

class SkillDoctorInput extends Input {
  SkillDoctorInput();

  factory SkillDoctorInput.fromCliRequest(CliRequest req) => SkillDoctorInput();

  /// Takes nothing on purpose. Doctor's job is to report the machine as it is,
  /// and a filter would let a user narrow away the thing that is wrong.
  static const List<CliParam> params = [];

  @override
  List<CliParam> get schemaFields => params;

  @override
  Map<String, dynamic> toJson() => const {};
}

class SkillDoctorOutput extends Output {
  SkillDoctorOutput({
    required this.detected,
    required this.undetected,
    required this.ledgerPath,
    required this.ledgerExists,
    required this.repositoryRoot,
    required this.owned,
    required this.drifted,
    required this.foreign,
  });

  final List<String> detected;
  final List<String> undetected;
  final String ledgerPath;
  final bool ledgerExists;
  final String? repositoryRoot;

  /// Units this consumer owns and which are intact.
  final List<String> owned;

  /// Units it owns whose destination no longer matches what it recorded — PRD
  /// 10.2 state 4, and the reason `doctor` exists as a route of its own.
  final List<String> drifted;

  /// Units another consumer owns, which this one will never disturb (state 5).
  final List<String> foreign;

  @override
  Map<String, dynamic> toJson() => {
    'detectedHosts': detected,
    'undetectedHosts': undetected,
    'ledger': {'path': ledgerPath, 'exists': ledgerExists},
    'repositoryRoot': repositoryRoot,
    'owned': owned,
    'drifted': drifted,
    'ownedByOthers': foreign,
  };

  /// Drift is a finding, not a failure: nothing is broken, something changed.
  @override
  int get exitCode => drifted.isEmpty ? ExitCode.ok : ExitCode.conflict;

  @override
  String? toText() {
    final lines = <String>[
      'Hosts detected:   ${detected.isEmpty ? '(none)' : detected.join(', ')}',
      'Hosts not found:  ${undetected.isEmpty ? '(none)' : undetected.join(', ')}',
      'Repository root:  ${repositoryRoot ?? '(not in a repository; --scope=repo will refuse)'}',
      'Ledger:           $ledgerPath${ledgerExists ? '' : '  (not written yet)'}',
      '',
      'Deployed by skillwire_cli, intact:  ${owned.length}',
      'Deployed by another consumer:       ${foreign.length}',
      'Modified since deployment:          ${drifted.length}',
    ];
    if (drifted.isNotEmpty) {
      lines.add('');
      lines.add('Modified at the destination since they were deployed. Deploy '
          'will block on these rather than lose the edits:');
      for (final d in drifted) {
        lines.add('  $d');
      }
    }
    if (foreign.isNotEmpty) {
      lines.add('');
      lines.add('Owned by another consumer. Left untouched, with or without '
          '--force (R10.3):');
      for (final f in foreign) {
        lines.add('  $f');
      }
    }
    return lines.join('\n');
  }
}

/// `skill doctor` — diagnose drift without mutating (PRD 12.2).
///
/// It reads the ledger rather than the catalogue, because its question is about
/// the machine, not about this release: what is out there, who owns it, and has
/// any of it changed underneath the consumer that put it there.
class SkillDoctorCommand implements Query<SkillDoctorInput, SkillDoctorOutput> {
  SkillDoctorCommand(this.input, {required this.workspace});

  @override
  final SkillDoctorInput input;

  final Workspace workspace;

  @override
  String? validate() => null;

  @override
  Future<SkillDoctorOutput> execute() async {
    final detected = workspace.detectedHosts;
    final ledger = workspace.ledgerFile.read();

    final owned = <String>[];
    final drifted = <String>[];
    final foreign = <String>[];

    for (final entry in ledger.rows.entries) {
      final label = '${entry.key.artifact} @ ${entry.value.resolvedDestinationPath}';
      if (entry.value.owningConsumer != actingConsumer) {
        foreign.add('$label  (${entry.value.owningConsumer})');
        continue;
      }
      final actual = contentHash(readTree(entry.value.resolvedDestinationPath));
      if (actual == entry.value.contentHash) {
        owned.add(label);
      } else {
        drifted.add(label);
      }
    }

    for (final list in [owned, drifted, foreign]) {
      list.sort();
    }

    return SkillDoctorOutput(
      detected: detected.toList()..sort(),
      undetected: [
        for (final id in workspace.matrix.hostIds)
          if (!detected.contains(id)) id,
      ],
      ledgerPath: workspace.ledgerFile.path,
      ledgerExists: workspace.ledgerFile.exists,
      repositoryRoot: workspace.repositoryRoot,
      owned: owned,
      drifted: drifted,
      foreign: foreign,
    );
  }
}
