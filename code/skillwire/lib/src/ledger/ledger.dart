import 'dart:convert';

import '../domain/unit.dart';
import '../errors.dart';
import '../reconcile/state.dart';

/// Where an artifact came from before materialisation.
enum SourceType {
  /// A directory on this machine — a consumer's own assets, usually.
  local,

  /// A git reference.
  git;

  String get token => name;

  static SourceType fromToken(String t) => SourceType.values.firstWhere(
    (v) => v.token == t,
    orElse: () => throw ArgumentError.value(t, 'token', 'not a SourceType'),
  );
}

/// One ledger row: everything R11.3 requires, and nothing else.
class LedgerRow {
  const LedgerRow({
    required this.sourceType,
    required this.sourceReference,
    required this.resolvedDestinationPath,
    required this.contentHash,
    required this.owningConsumer,
    required this.artifactVersion,
    required this.created,
    required this.updated,
  });

  final SourceType sourceType;
  final String sourceReference;

  /// The directory actually written to. R6.2 requires the choice among a host's
  /// several directories to be recorded, and this is where it is recorded.
  final String resolvedDestinationPath;

  final String contentHash;

  /// The consumer that deployed this unit. Ownership lives here and nowhere
  /// else — not in a filename prefix, not in a frontmatter key (R13.8).
  final String owningConsumer;

  final String artifactVersion;

  /// When the acting consumer first deployed **or adopted** this unit.
  final DateTime created;

  /// When it last wrote to the destination. `keep` advances neither; `adopt`
  /// sets both to the same instant, since no write occurred — which makes an
  /// adopted row distinguishable from a deployed one on inspection (R11.3).
  final DateTime updated;

  /// True when this row was adopted rather than deployed (R10.6).
  bool get wasAdopted => created.isAtSameMomentAs(updated);

  /// The narrow view reconciliation needs. Everything else here is provenance
  /// for a human, not input to a verb.
  LedgerRecord get record =>
      LedgerRecord(owner: owningConsumer, contentHash: contentHash);

  Map<String, dynamic> toJson() => {
    'sourceType': sourceType.token,
    'sourceReference': sourceReference,
    'resolvedDestinationPath': resolvedDestinationPath,
    'contentHash': contentHash,
    'owningConsumer': owningConsumer,
    'artifactVersion': artifactVersion,
    'created': created.toUtc().toIso8601String(),
    'updated': updated.toUtc().toIso8601String(),
  };

  factory LedgerRow.fromJson(Map<String, dynamic> json) => LedgerRow(
    sourceType: SourceType.fromToken(json['sourceType'] as String),
    sourceReference: json['sourceReference'] as String,
    resolvedDestinationPath: json['resolvedDestinationPath'] as String,
    contentHash: json['contentHash'] as String,
    owningConsumer: json['owningConsumer'] as String,
    artifactVersion: json['artifactVersion'] as String,
    created: DateTime.parse(json['created'] as String),
    updated: DateTime.parse(json['updated'] as String),
  );
}

/// What is deployed on this machine.
///
/// **One per machine, shared by every consumer** (R11.5). Not one per consumer:
/// PRD 10.2 state 5 asks *which other consumer owns this*, and a consumer that
/// could read only its own ledger could not answer — least of all for a
/// consumer it has never heard of.
///
/// This class is the value and its codec, with no I/O. `LedgerFile` is the edge.
class Ledger {
  Ledger({Map<Unit, LedgerRow>? rows, this.schemaVersion = currentSchemaVersion})
    : _rows = {...?rows};

  /// Bumped when the on-disk shape changes. Present from the first write
  /// (R11.6) so that a future reader never has to guess which shape it has.
  static const currentSchemaVersion = 1;

  final int schemaVersion;
  final Map<Unit, LedgerRow> _rows;

  Map<Unit, LedgerRow> get rows => Map.unmodifiable(_rows);

  LedgerRow? operator [](Unit unit) => _rows[unit];

  /// What reconciliation needs for [unit], or null when no consumer recorded it.
  LedgerRecord? recordFor(Unit unit) => _rows[unit]?.record;

  void put(Unit unit, LedgerRow row) => _rows[unit] = row;

  void remove(Unit unit) => _rows.remove(unit);

  /// Rows owned by [consumer], for a `skill list` scoped to one CLI.
  Map<Unit, LedgerRow> ownedBy(String consumer) => {
    for (final e in _rows.entries)
      if (e.value.owningConsumer == consumer) e.key: e.value,
  };

  String encode() => const JsonEncoder.withIndent('  ').convert({
    'schemaVersion': schemaVersion,
    // Sorted so two machines that deployed the same things produce
    // byte-identical files, which makes a diff of two ledgers legible.
    'units': {
      for (final key in (_rows.keys.toList()..sort((a, b) => a.key.compareTo(b.key))))
        key.key: _rows[key]!.toJson(),
    },
  });

  /// Parse a ledger document.
  ///
  /// Throws [LedgerUnreadable] rather than returning an empty ledger. Treating
  /// a corrupt file as empty would reclassify every deployed unit into state 6
  /// and, under `--force`, invite adopting or overwriting artifacts whose real
  /// ownership was merely unreadable.
  factory Ledger.decode(String text, {required String path}) {
    try {
      final doc = jsonDecode(text);
      if (doc is! Map<String, dynamic>) {
        throw const FormatException('the document is not an object');
      }
      final version = doc['schemaVersion'];
      if (version is! int) {
        throw const FormatException('no schemaVersion');
      }
      if (version > currentSchemaVersion) {
        throw FormatException(
          'schema version $version was written by a newer skillwire; '
          'this build understands $currentSchemaVersion',
        );
      }
      final units = doc['units'] as Map<String, dynamic>? ?? const {};
      return Ledger(
        schemaVersion: version,
        rows: {
          for (final e in units.entries)
            Unit.parse(e.key): LedgerRow.fromJson(e.value as Map<String, dynamic>),
        },
      );
    } on LedgerUnreadable {
      rethrow;
    } catch (e) {
      throw LedgerUnreadable(path: path, cause: '$e');
    }
  }
}
