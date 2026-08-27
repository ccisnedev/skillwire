import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;
import 'package:skillwire/skillwire.dart';


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

  bool get isClean => duplicates.isEmpty && results.every((r) => r.isValid);

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
    required this.consumer,
    required this.detected,
    required this.undetected,
    required this.ledgerPath,
    required this.ledgerExists,
    required this.repositoryRoot,
    required this.diagnosis,
    required this.provenance,
  });

  /// The CLI this report speaks for. Doctor says "deployed by macss" or
  /// "deployed by skillwire_cli" because a shared ledger holds rows for all of
  /// them, and a count with no owner beside it means nothing.
  final String consumer;

  final List<String> detected;
  final List<String> undetected;
  final String ledgerPath;
  final bool ledgerExists;
  final String? repositoryRoot;
  final Diagnosis diagnosis;

  /// Where each matrix path came from, and when it was read (R14.2).
  final List<String> provenance;

  @override
  Map<String, dynamic> toJson() => {
    'consumer': consumer,
    'detectedHosts': detected,
    'undetectedHosts': undetected,
    'ledger': {'path': ledgerPath, 'exists': ledgerExists},
    'repositoryRoot': repositoryRoot,
    'healthy': diagnosis.isHealthy,
    'claims': {
      for (final claim in LedgerClaim.values)
        claim.name: [
          for (final c in diagnosis.claims(claim))
            {
              'unit': c.unit.key,
              'destination': c.row.resolvedDestinationPath,
              'owner': c.row.owningConsumer,
              'remedy': c.remedy,
            },
        ],
    },
    'unmanaged': [
      for (final u in diagnosis.unmanaged)
        {'name': u.name, 'path': u.path, 'declaredOrigin': u.declaredOrigin},
    ],
    'duplicates': [
      for (final d in diagnosis.duplicates)
        {
          'artifact': d.artifact,
          'host': d.host,
          'scope': d.scope.token,
          'paths': d.paths,
          'expected': d.isExpected,
        },
    ],
  };

  /// Drift, absence and an avoidable duplicate are findings to act on. Another
  /// consumer's artifacts and unknown occupants are not: an ordinary machine has
  /// both, and a tool that calls that unhealthy teaches its user to ignore the
  /// word.
  @override
  int get exitCode => diagnosis.isHealthy ? ExitCode.ok : ExitCode.conflict;

  @override
  String? toText() {
    final out = <String>[
      'The machine',
      '  Hosts detected:   ${detected.isEmpty ? '(none)' : detected.join(', ')}',
      '  Hosts not found:  ${undetected.isEmpty ? '(none)' : undetected.join(', ')}',
      '  Repository root:  ${repositoryRoot ?? '(not in a repository; --scope=repo will refuse)'}',
      '  Ledger:           $ledgerPath${ledgerExists ? '' : '  (not written yet)'}',
      '',
      'Verdict',
      '  $_verdict',
      '',
      'What the ledger claims',
    ];

    if (diagnosis.allClaims.isEmpty) {
      out.add('  Nothing is recorded yet.');
    } else {
      for (final claim in LedgerClaim.values) {
        final rows = diagnosis.claims(claim);
        if (rows.isEmpty) continue;
        out.add('  ${_label(claim)}: ${rows.length}');
        // Intact rows are counted, not listed: a wall of correct lines buries
        // the two that are not.
        if (claim == LedgerClaim.intact) continue;
        for (final r in rows) {
          out.add('    ${r.unit.artifact} @ ${r.row.resolvedDestinationPath}');
          out.add('      ${r.remedy}');
        }
      }
    }

    out.add('');
    out.add('What the ledger does not know');
    if (diagnosis.unmanaged.isEmpty) {
      out.add('  Nothing in reach of a detected host is unaccounted for.');
    } else {
      // Grouped by directory rather than one entry per artifact. Five names in
      // two directories is six lines grouped and thirty listed, and the grouped
      // form is the one that shows the shape: the same five things, twice over.
      final byDirectory = <String, List<UnmanagedArtifact>>{};
      for (final u in diagnosis.unmanaged) {
        byDirectory.putIfAbsent(p.dirname(u.path), () => []).add(u);
      }
      for (final directory in byDirectory.keys.toList()..sort()) {
        final occupants = byDirectory[directory]!;
        final readers =
            occupants.first.readBy.map((r) => '${r.$1}/${r.$2.token}').join(', ');
        out.add('  $directory   (read by $readers)');
        out.add('    ${(occupants.map((u) => u.name).toList()..sort()).join(', ')}');
        final declared = {
          for (final u in occupants)
            if (u.declaredOrigin != null) u.declaredOrigin!,
        };
        if (declared.isNotEmpty) {
          out.add('    appears to be from: ${(declared.toList()..sort()).join(', ')}');
        }
      }
      out.add('  Left alone. Deploying an artifact of the same name over one of');
      out.add('  these blocks (PRD 10.2 state 6); --force adopts it only when the');
      out.add('  contents already match (R10.6).');
    }

    if (diagnosis.duplicates.isNotEmpty) {
      out.add('');
      out.add('One artifact, more than one directory');

      final actionable = diagnosis.actionableDuplicates;
      if (actionable.isNotEmpty) {
        out.add('  Needs attention — ${actionable.length}:');
        for (final d in actionable) {
          out.add('    ${d.artifact}  (seen twice by ${d.host} at ${d.scope.token})');
          for (final path in d.paths) {
            out.add('      $path');
          }
        }
      }

      // Counted and named on one line, never spelled out. Nobody can do
      // anything about these, so detail would only bury what they can.
      final expected =
          [for (final d in diagnosis.duplicates) if (d.isExpected) d];
      if (expected.isNotEmpty) {
        final names = (expected.map((d) => d.artifact).toSet().toList()..sort());
        out.add('  Irreducible (PRD 7.4) — ${names.length}: ${names.join(', ')}');
        out.add('    Deployed to two hosts at global scope, one of which reads');
        out.add("    the other's directory and cannot be prevented.");
      }
    }

    out.add('');
    out.add('Where the host paths came from');
    for (final line in provenance) {
      out.add('  $line');
    }
    out.add('  R14.2: a row whose cited version is behind the installed one is');
    out.add('  unverified again. Re-read the host before trusting it.');

    return out.join('\n');
  }

  /// One line saying what the exit code means, because an exit code without a
  /// sentence beside it teaches the reader to stop looking at exit codes.
  String get _verdict {
    if (diagnosis.isHealthy) {
      return diagnosis.unmanaged.isEmpty
          ? 'Everything the ledger records is where it was put, and nothing '
                'else is in reach.'
          : 'Everything the ledger records is where it was put. Other tools '
                'have artifacts here too; nothing to act on.';
    }
    final findings = [
      if (diagnosis.claims(LedgerClaim.missing).isNotEmpty)
        '${diagnosis.claims(LedgerClaim.missing).length} gone from the destination',
      if (diagnosis.claims(LedgerClaim.drifted).isNotEmpty)
        '${diagnosis.claims(LedgerClaim.drifted).length} modified since deployment',
      if (diagnosis.actionableDuplicates.isNotEmpty)
        '${diagnosis.actionableDuplicates.length} visible to one host from two directories',
    ];
    return 'Needs attention: ${findings.join('; ')}.';
  }

  String _label(LedgerClaim claim) => switch (claim) {
    LedgerClaim.intact => 'Deployed by $consumer, intact',
    LedgerClaim.missing => 'Recorded, but gone from the destination',
    LedgerClaim.drifted => 'Modified since deployment',
    LedgerClaim.foreign => 'Deployed by another consumer',
  };
}

/// `skill doctor` — report the machine without mutating it (PRD 12.2).
///
/// Its question is not "what did I deploy": the ledger answers that alone. It is
/// **whether what the ledger believes about this machine is still true, and
/// whether anything is here that the ledger does not know about.** Everything it
/// reports follows from that one question, and it creates nothing to find out.
class SkillDoctorCommand implements Query<SkillDoctorInput, SkillDoctorOutput> {
  SkillDoctorCommand(
    this.input, {
    required this.consumer,
    required this.workspace,
  });

  /// The CLI on whose behalf this run acts (see `buildSkillModule`).
  final String consumer;

  @override
  final SkillDoctorInput input;

  final Workspace workspace;

  @override
  String? validate() => null;

  @override
  Future<SkillDoctorOutput> execute() async {
    final detected = workspace.detectedHosts;
    final ledger = workspace.ledgerFile.read();
    final validator =
        SkillValidator(reservedNames: workspace.matrix.reservedNames);

    return SkillDoctorOutput(
      consumer: consumer,
      detected: detected.toList()..sort(),
      undetected: [
        for (final id in workspace.matrix.hostIds)
          if (!detected.contains(id)) id,
      ],
      ledgerPath: workspace.ledgerFile.path,
      ledgerExists: workspace.ledgerFile.exists,
      repositoryRoot: workspace.repositoryRoot,
      diagnosis: diagnose(
        ledger: ledger,
        actingConsumer: consumer,
        destinationHashes: destinationHashes(ledger),
        found: scanHosts(workspace: workspace, validator: validator),
      ),
      provenance: _provenance(detected),
    );
  }

  /// One line per detected host, naming what its paths were read from.
  ///
  /// Reported rather than checked. Verifying a row against the installed version
  /// means running the host's own binary, and a diagnostic that spawns processes
  /// is a different kind of tool from one that reads directories. The human
  /// compares; R14.2 says what to do when the versions diverge.
  List<String> _provenance(Set<String> detected) => [
    for (final id in detected.toList()..sort())
      for (final scope in Scope.values)
        for (final d in workspace.matrix.host(id).skills[scope] ??
            const <HostDirectory>[])
          '$id/${scope.token}  ${d.template}  <- ${d.provenance.source} '
              '(${d.provenance.read})',
  ];
}
