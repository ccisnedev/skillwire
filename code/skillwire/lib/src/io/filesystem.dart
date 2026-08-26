import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../domain/unit.dart';
import '../errors.dart';
import '../ledger/ledger.dart';
import '../reconcile/state.dart';
import '../reconcile/steps.dart';

/// Read an artifact directory into the shape reconciliation understands.
///
/// This is materialisation's output and reconciliation's input: a map of
/// relative path to bytes. Everything past this point is ignorant of how the
/// directory came to exist (R8.1).
///
/// Symlinks are an error rather than a silent skip. A symlinked file inside a
/// deployed artifact would hash as its target's bytes today and something else
/// tomorrow, with nothing recording that the link was ever there.
Map<String, Uint8List> readTree(String directory) {
  final dir = Directory(directory);
  if (!dir.existsSync()) return const {};

  final tree = <String, Uint8List>{};
  for (final entity in dir.listSync(recursive: true, followLinks: false)) {
    final relative = p.relative(entity.path, from: directory).replaceAll(r'\', '/');
    if (entity is Link) {
      throw SkillInvalid(
        artifact: p.basename(directory),
        findings: ['$relative is a symlink; artifacts are copied, not linked'],
      );
    }
    if (entity is File) tree[relative] = entity.readAsBytesSync();
  }
  return tree;
}

/// The real destination for a plan's effects: the filesystem, plus the ledger.
///
/// The only class in the package that writes anything. Reconciliation decided
/// with no I/O (R10.4); this is the "one write after" at the other edge.
class FilesystemSink implements DeploymentSink {
  FilesystemSink({
    required this.ledgerFile,
    required this.actingConsumer,
    required this.sourceType,
    required this.sourceReference,
    required this.artifactVersions,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final LedgerFile ledgerFile;

  /// The consumer on whose behalf this run acts. Written into every row it
  /// creates, and the only thing that makes state 5 answerable.
  final String actingConsumer;

  final SourceType sourceType;
  final String sourceReference;

  /// Artifact name to `metadata.version` (R13.6), for the ledger's
  /// `artifactVersion` field.
  final Map<String, String> artifactVersions;

  final DateTime Function() _now;

  @override
  Future<void> writeTree(String destination, Map<String, Uint8List> tree) async {
    final dir = Directory(destination);

    // Written to a sibling and renamed into place, so a run interrupted midway
    // leaves either the old artifact or the new one — never half of each, which
    // a host would happily load.
    final staging = Directory('$destination.skillwire-staging');
    if (staging.existsSync()) staging.deleteSync(recursive: true);
    staging.createSync(recursive: true);

    for (final entry in tree.entries) {
      final file = File(p.join(staging.path, entry.key));
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(entry.value);
    }

    if (dir.existsSync()) dir.deleteSync(recursive: true);
    staging.renameSync(destination);
  }

  @override
  Future<void> deleteTree(String destination) async {
    final dir = Directory(destination);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }

  @override
  Future<void> record(Unit unit, String destination, String contentHash) async {
    final ledger = ledgerFile.read();
    final existing = ledger[unit];
    final now = _now();
    ledger.put(
      unit,
      LedgerRow(
        sourceType: sourceType,
        sourceReference: sourceReference,
        resolvedDestinationPath: destination,
        contentHash: contentHash,
        owningConsumer: actingConsumer,
        artifactVersion: artifactVersions[unit.artifact] ?? '',
        created: existing?.created ?? now,
        updated: now,
      ),
    );
    ledgerFile.write(ledger);
  }

  @override
  Future<void> forget(Unit unit) async {
    final ledger = ledgerFile.read();
    ledger.remove(unit);
    ledgerFile.write(ledger);
  }

}

/// The ledger on disk.
///
/// One per machine at `$SKILLWIRE_HOME/ledger.json`, falling back to
/// `~/.skillwire/ledger.json` only when the variable is unset (R11.5) — the
/// same resolution rule R6.1 applies to `CODEX_HOME`, so it uses the same
/// helper shape.
class LedgerFile {
  LedgerFile(this.path);

  /// Resolve the path the way R11.5 specifies.
  factory LedgerFile.resolve({
    required String home,
    required Map<String, String> environment,
  }) {
    final override = environment['SKILLWIRE_HOME'];
    final root = (override == null || override.isEmpty)
        ? p.join(home, '.skillwire')
        : override;
    return LedgerFile(p.join(root, 'ledger.json'));
  }

  final String path;

  bool get exists => File(path).existsSync();

  /// The ledger, or an empty one when the file does not exist yet.
  ///
  /// Absent and unreadable are different: absent is a first run, unreadable
  /// throws (R11.1's neighbour concern — a corrupt file must never read as
  /// "nothing is deployed").
  Ledger read() {
    final file = File(path);
    if (!file.existsSync()) return Ledger();
    return Ledger.decode(file.readAsStringSync(), path: path);
  }

  /// Write atomically: a temporary file in the same directory, then rename over
  /// the target (R11.6). Three CLIs share this file, and a write interrupted
  /// midway would leave the other two unable to tell what they own.
  void write(Ledger ledger) {
    final file = File(path);
    file.parent.createSync(recursive: true);
    final temp = File('$path.tmp');
    temp.writeAsStringSync(ledger.encode(), flush: true);
    if (file.existsSync()) file.deleteSync();
    temp.renameSync(path);
  }
}

/// Read what is at a destination, for the "one read before" of R10.4.
Observed observe({
  required String destination,
  required Unit unit,
  required Ledger ledger,
  required String Function(Map<String, Uint8List>) hash,
}) {
  final dir = Directory(destination);
  if (!dir.existsSync()) {
    return Observed(ledger: ledger.recordFor(unit));
  }
  return Observed(
    contentHash: hash(readTree(destination)),
    ledger: ledger.recordFor(unit),
  );
}
