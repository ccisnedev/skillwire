import 'package:yaml/yaml.dart';

import '../domain/scope.dart';
import '../errors.dart';
import 'matrix_data.dart';

/// Where a path came from, and when it was read (R6.4, R14.2).
///
/// A row without one resolves to a throw. Non-negotiable rule 5: never present
/// an unverified path as a fact — and a path handed to a caller who will write
/// to it has been presented as one.
class Provenance {
  const Provenance({required this.source, required this.read});

  /// The artifact and version it was read from.
  final String source;

  /// The date it was read, ISO-8601. R14.2 makes a row whose cited version is
  /// behind the installed one unverified again.
  final String read;

  static const unverified = Provenance(source: 'unverified', read: '');

  bool get isVerified => source != 'unverified';
}

/// One directory a host reads, at one scope.
class HostDirectory {
  const HostDirectory({
    required this.template,
    required this.provenance,
    this.fallback,
    this.aliases = const [],
  });

  /// The path with `~` and `$VAR` still in it.
  final String template;

  /// Used when [template]'s environment variable is unset — Codex's
  /// `~/.codex/skills` behind `$CODEX_HOME/skills` (R6.1).
  final String? fallback;

  /// Other spellings of the *same* destination.
  ///
  /// Observed, never written to. OpenCode reads both `skill` and `skills` under
  /// a brace glob, so the two are one destination for the one-path invariant
  /// (R6.5); Antigravity accepts four spellings of its workspace root (R6.6).
  final List<String> aliases;

  final Provenance provenance;
}

/// A host as the matrix describes it. No behaviour, no per-host branching.
class HostEntry {
  const HostEntry({
    required this.id,
    required this.name,
    required this.marker,
    required this.skills,
  });

  final String id;
  final String name;

  /// The host's config root. Its absence means the host is not installed, so an
  /// unqualified run skips it rather than creating a tree nothing will read.
  final String marker;

  final Map<Scope, List<HostDirectory>> skills;
}

/// A directory one host reads that another host owns (PRD 7.1).
class VisibilityEdge {
  const VisibilityEdge({
    required this.host,
    required this.reads,
    required this.scope,
    required this.source,
  });

  final String host;
  final String reads;
  final Scope scope;
  final String source;
}

/// The parsed matrix.
///
/// Everything in here comes from [hostMatrixYaml]. There is no `switch` on host
/// id in this file or anywhere else under `lib/`, which is what makes R6.3's
/// promise — adding a host is a data change — true rather than aspirational.
class HostMatrix {
  HostMatrix._({
    required this.hosts,
    required this.visibility,
    required this.reservedNames,
    required this.neverDestinations,
  });

  final Map<String, HostEntry> hosts;
  final List<VisibilityEdge> visibility;

  /// Names no artifact may take, lowercased. Currently `synced` (R6.11).
  final Map<String, String> reservedNames;

  /// Paths a host reads that are never written to (R6.10).
  final Map<String, String> neverDestinations;

  /// Parse the built-in matrix.
  factory HostMatrix.builtIn() => HostMatrix.parse(hostMatrixYaml);

  /// Parse an arbitrary matrix document.
  ///
  /// Public because it is the test for R6.3: a fabricated host in a fabricated
  /// document must resolve with no change to any Dart file. If this needed a
  /// code change to accept a new host, the matrix would not be data.
  factory HostMatrix.parse(String yaml) {
    final doc = loadYaml(yaml) as YamlMap;

    Provenance provenanceOf(YamlMap dir) {
      final p = dir['provenance'];
      if (p is! YamlMap) return Provenance.unverified;
      return Provenance(
        source: p['source'] as String? ?? 'unverified',
        read: p['read'] as String? ?? '',
      );
    }

    List<HostDirectory> directoriesOf(dynamic list) => [
      for (final d in (list as YamlList? ?? YamlList()).cast<YamlMap>())
        HostDirectory(
          template: d['path'] as String,
          fallback: d['fallback'] as String?,
          aliases: [...?(d['aliases'] as YamlList?)?.cast<String>()],
          provenance: provenanceOf(d),
        ),
    ];

    final hosts = <String, HostEntry>{};
    for (final entry in (doc['hosts'] as YamlMap).entries) {
      final id = entry.key as String;
      final h = entry.value as YamlMap;
      final skills = h['skills'] as YamlMap? ?? YamlMap();
      hosts[id] = HostEntry(
        id: id,
        name: h['name'] as String? ?? id,
        marker: h['marker'] as String? ?? '',
        skills: {
          for (final scope in Scope.values)
            scope: directoriesOf(skills[scope.token]),
        },
      );
    }

    return HostMatrix._(
      hosts: hosts,
      visibility: [
        for (final e in (doc['visibility'] as YamlList? ?? YamlList()).cast<YamlMap>())
          VisibilityEdge(
            host: e['host'] as String,
            reads: e['reads'] as String,
            scope: Scope.fromToken(e['scope'] as String),
            source: e['source'] as String? ?? '',
          ),
      ],
      reservedNames: {
        for (final r in (doc['reserved'] as YamlList? ?? YamlList()).cast<YamlMap>())
          (r['name'] as String).toLowerCase(): r['reason'] as String? ?? '',
      },
      neverDestinations: {
        for (final n in (doc['never_destinations'] as YamlList? ?? YamlList())
            .cast<YamlMap>())
          n['path'] as String: n['reason'] as String? ?? '',
      },
    );
  }

  /// Every host id the matrix knows, sorted.
  List<String> get hostIds => hosts.keys.toList()..sort();

  HostEntry host(String id) => hosts[id] ?? (throw UnknownHost(id));

  /// The directory this package **writes** to for [id] at [scope].
  ///
  /// R6.2: where a host lists several directories, exactly one is resolved, and
  /// the choice is recorded in the ledger. The choice is the first entry in the
  /// matrix — a preference order expressed as data (R6.3), reviewable when a
  /// host's directory list changes.
  ///
  /// Throws [UnverifiedHostPath] when the chosen row carries no provenance,
  /// which is R6.4 refusing rather than guessing.
  HostDirectory destination(String id, Scope scope) {
    final dirs = host(id).skills[scope] ?? const [];
    if (dirs.isEmpty) throw UnverifiedHostPath(host: id, scope: scope);
    final chosen = dirs.first;
    if (!chosen.provenance.isVerified) {
      throw UnverifiedHostPath(host: id, scope: scope);
    }
    return chosen;
  }

  /// Every directory this package **observes** for [id] at [scope]: the host's
  /// own directories, their alias spellings, and every directory the visibility
  /// graph says this host reads.
  ///
  /// Wider than [destination] on purpose (R6.9). An artifact sitting anywhere
  /// the host reads participates in the one-path invariant whether or not this
  /// package would ever write there, and a collision the package cannot see is
  /// one it cannot report.
  ///
  /// The borrowed directories come from [visibility] rather than being repeated
  /// in each host's own list. They are already stated there, and a fact written
  /// twice is a fact that can disagree with itself.
  List<String> observed(String id, Scope scope) {
    final out = <String>[];
    void add(String path) {
      if (!out.contains(path)) out.add(path);
    }

    for (final d in host(id).skills[scope] ?? const <HostDirectory>[]) {
      add(d.template);
      d.aliases.forEach(add);
    }
    for (final edge in visibility) {
      if (edge.host == id && edge.scope == scope) add(edge.reads);
    }
    return out;
  }

  /// Detected hosts, other than [id], that also read [directory] at [scope]
  /// (R7.2, R7.3, R7.4).
  List<VisibilityEdge> alsoRead({
    required String directory,
    required Scope scope,
    required String excluding,
    required Set<String> detected,
  }) => [
    for (final e in visibility)
      if (e.scope == scope &&
          e.host != excluding &&
          detected.contains(e.host) &&
          e.reads == directory)
        e,
  ];

  /// Why [name] may not be used, or null when it may (R6.11).
  String? reservedReason(String name) => reservedNames[name.toLowerCase()];
}
