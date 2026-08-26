import 'kind.dart';
import 'scope.dart';

/// The atom of reconciliation: PRD 10.1's tuple
/// `(artifact, kind, host, scope, subagent?)`.
///
/// Everything downstream is keyed by this. The ledger (R11.2), the plan, the
/// manifest and every `block` message name a unit, so it is a value type with
/// real equality rather than a bag of strings passed around in parallel.
///
/// [host] is a `String` and not an enum on purpose. R6.3 puts the host matrix
/// in a data file so that adding a host is a data change; an enum here would
/// put the host list back in code and make that promise false.
class Unit {
  const Unit({
    required this.artifact,
    required this.kind,
    required this.host,
    required this.scope,
    this.subagent,
  });

  /// The artifact's name, which for a skill equals its directory name — the
  /// Agent Skills specification requires the two to match (PRD 13.1).
  final String artifact;

  final Kind kind;

  /// A host id from the matrix: `claude`, `codex`, `antigravity`, `opencode`,
  /// `copilot`.
  final String host;

  final Scope scope;

  /// The subagent this artifact is scoped to, where a host supports it.
  /// Null for the ordinary case of an artifact visible to the whole host.
  final String? subagent;

  /// Field separator for [key].
  ///
  /// `|` is safe against every component: host ids are matrix-defined words,
  /// artifact names are constrained by the specification to lowercase
  /// alphanumerics and hyphens (PRD 13.1), and kind and scope are closed sets.
  static const _sep = '|';

  /// A stable, flat identity for the ledger and the manifest.
  ///
  /// The component order is PRD 10.1's, verbatim. It is written to disk, so it
  /// is built from each part's `token` rather than from Dart's `name`: renaming
  /// an enum member must not silently orphan every ledger row.
  String get key => [
    artifact,
    kind.token,
    host,
    scope.token,
    subagent ?? '',
  ].join(_sep);

  static Unit parse(String key) {
    final parts = key.split(_sep);
    if (parts.length != 5) {
      throw ArgumentError.value(key, 'key', 'expected 5 fields, got ${parts.length}');
    }
    return Unit(
      artifact: parts[0],
      kind: Kind.fromToken(parts[1]),
      host: parts[2],
      scope: Scope.fromToken(parts[3]),
      subagent: parts[4].isEmpty ? null : parts[4],
    );
  }

  @override
  bool operator ==(Object other) => other is Unit && other.key == key;

  @override
  int get hashCode => key.hashCode;

  /// Reads as the tuple it is, so a failing expectation names the unit.
  @override
  String toString() =>
      'Unit($artifact, ${kind.token}, $host, ${scope.token}'
      '${subagent == null ? '' : ', subagent: $subagent'})';
}
