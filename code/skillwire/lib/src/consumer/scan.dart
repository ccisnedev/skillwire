import 'dart:io' as io;

import 'package:path/path.dart' as p;

import '../diagnose/diagnosis.dart';
import '../domain/scope.dart';
import '../errors.dart';
import '../hash/content_hash.dart';
import '../io/filesystem.dart';
import '../ledger/ledger.dart';
import '../validate/skill_validator.dart';
import 'workspace.dart';


/// Walk every directory a detected host reads, and report what is in them.
///
/// This is the read that `skill doctor` decides on, and the only reason doctor
/// can answer a question wider than "what did I deploy". It **creates nothing**:
/// a diagnostic that leaves a directory behind is not a diagnosis, and a host
/// that has never been given a skill has no skills directory to find.
///
/// Identity is the physical path. `~/.claude/skills` sits in OpenCode's observed
/// set as well as Claude Code's own, so a scan keyed on `(host, scope)` would
/// report one directory twice and turn a single fact into two findings.
List<FoundArtifact> scanHosts({
  required Workspace workspace,
  required SkillValidator validator,
}) {
  final matrix = workspace.matrix;
  final resolver = workspace.resolver;

  // Physical path -> the hosts that read it, in discovery order.
  final readers = <String, List<HostScope>>{};
  final artifacts = <String, _Candidate>{};

  for (final host in (workspace.detectedHosts.toList()..sort())) {
    for (final scope in Scope.values) {
      // R6.9 — observation is wider than the destination: alias spellings
      // included, because a collision the package cannot see is one it cannot
      // report.
      final List<String> directories;
      try {
        directories = resolver.observedFor(matrix, host, scope);
      } on SkillwireError {
        // Outside a repository, `repo` scope has nothing to resolve (R12.3).
        // Not an error here: doctor reports the machine it is on.
        continue;
      }

      for (final directory in directories) {
        final dir = io.Directory(directory);
        if (!dir.existsSync()) continue;

        for (final entry in dir.listSync().whereType<io.Directory>()) {
          final name = p.basename(entry.path);

          // `synced` belongs to Claude Code, which fills it from claude.ai
          // (R6.11). It is not an unknown occupant; it is a known one.
          if (matrix.reservedReason(name) != null) continue;
          if (!io.File(p.join(entry.path, 'SKILL.md')).existsSync()) continue;

          final path = p.normalize(entry.path);
          readers.putIfAbsent(path, () => []);
          if (!readers[path]!.any((r) => r.$1 == host && r.$2 == scope)) {
            readers[path]!.add((host, scope));
          }
          artifacts[path] ??= _Candidate(path: path, name: name);
        }
      }
    }
  }

  return [
    for (final candidate in artifacts.values)
      FoundArtifact(
        path: candidate.path,
        name: candidate.name,
        declaredOrigin: _declaredOrigin(candidate.path, candidate.name, validator),
        readBy: readers[candidate.path]!,
      ),
  ];
}

class _Candidate {
  const _Candidate({required this.path, required this.name});
  final String path;
  final String name;
}

/// `metadata.skillwire-origin`, when the artifact declares one.
///
/// Read leniently: this is a directory somebody else may have written, and a
/// malformed one is a thing to report rather than a reason to fail. R13.8 makes
/// the value a courtesy in any case — it says who *appears* to have deployed
/// something, never who owns it.
String? _declaredOrigin(String path, String name, SkillValidator validator) {
  try {
    return validator
        .validate(directoryName: name, tree: readTree(path))
        .frontmatter
        ?.skillwireOrigin;
  } on Object {
    return null;
  }
}

/// What is at each destination the ledger records, or null where nothing is.
///
/// The other half of doctor's read. Separated from [scanHosts] because a ledger
/// row may point somewhere no host currently reads — a directory whose host was
/// uninstalled, for instance — and that row still has to be checked.
Map<String, String?> destinationHashes(Ledger ledger) => {
  for (final row in ledger.rows.values)
    row.resolvedDestinationPath:
        io.Directory(row.resolvedDestinationPath).existsSync()
            ? contentHash(readTree(row.resolvedDestinationPath))
            : null,
};
