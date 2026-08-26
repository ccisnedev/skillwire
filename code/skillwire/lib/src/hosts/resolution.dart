import 'package:path/path.dart' as p;

import '../domain/scope.dart';
import '../errors.dart';
import 'host_matrix.dart';

/// Turns a matrix template into an absolute path.
///
/// Pure given its inputs: the environment arrives as a map rather than being
/// read from `Platform`, so every expansion rule is testable and a test can
/// pose "what if `CODEX_HOME` is unset" without touching the real environment.
class PathResolver {
  const PathResolver({
    required this.home,
    required this.environment,
    this.repositoryRoot,
  });

  /// The user's home directory, for `~`.
  final String home;

  /// The environment, for `$VAR`.
  final Map<String, String> environment;

  /// The repository root, for `repo`-scope templates.
  ///
  /// Null outside a repository, which makes `repo` scope throw rather than fall
  /// back to `global` (R12.3). Falling back would deploy to a user's home when
  /// they asked for a project, which is the surprise rule 2 exists to prevent.
  final String? repositoryRoot;

  /// Expand [template], or null when it names an environment variable that is
  /// unset and has no fallback.
  String? expand(String template, {String? fallback}) {
    final varMatch = RegExp(r'^\$(\w+)(/.*)?$').firstMatch(template);
    if (varMatch != null) {
      final value = environment[varMatch.group(1)!];
      if (value == null || value.isEmpty) {
        return fallback == null ? null : expand(fallback);
      }
      return p.normalize(p.join(value, _stripLeadingSlash(varMatch.group(2) ?? '')));
    }
    if (template.startsWith('~/')) {
      return p.normalize(p.join(home, template.substring(2)));
    }
    return template;
  }

  /// The absolute directory this package writes to for [host] at [scope].
  ///
  /// Throws [UnverifiedHostPath] when the matrix row has no provenance (R6.4),
  /// and [RepoScopeOutsideRepository] when `repo` is asked for outside one
  /// (R12.3).
  String destinationFor(HostMatrix matrix, String host, Scope scope) {
    final dir = matrix.destination(host, scope);
    return _absolute(dir.template, scope, host, fallback: dir.fallback);
  }

  /// Every absolute directory to look in for [host] at [scope], alias spellings
  /// included (R6.9).
  List<String> observedFor(HostMatrix matrix, String host, Scope scope) {
    final out = <String>[];
    for (final template in matrix.observed(host, scope)) {
      final resolved = _tryAbsolute(template, scope);
      if (resolved != null) out.add(resolved);
    }
    return out;
  }

  String _absolute(String template, Scope scope, String host, {String? fallback}) {
    final resolved = _tryAbsolute(template, scope, fallback: fallback);
    if (resolved == null) throw UnverifiedHostPath(host: host, scope: scope);
    return resolved;
  }

  String? _tryAbsolute(String template, Scope scope, {String? fallback}) {
    final expanded = expand(template, fallback: fallback);
    if (expanded == null) return null;
    if (p.isAbsolute(expanded)) return p.normalize(expanded);

    // A relative template is repo-scope. R6.8: it resolves to the repository
    // ROOT and nowhere else, even though Codex and Antigravity also search
    // upward and Claude Code searches downward. Deploying into an intermediate
    // directory would make what a host loads depend on where the user happened
    // to be standing, which defeats G4.
    final root = repositoryRoot;
    if (root == null) throw RepoScopeOutsideRepository(p.current);
    return p.normalize(p.join(root, expanded));
  }

  static String _stripLeadingSlash(String s) =>
      s.startsWith('/') ? s.substring(1) : s;
}

/// Which hosts are present on this machine.
///
/// R7.4 lets only detected hosts be named in a plan's annotations, so detection
/// is what keeps a visibility warning from naming a tool the user has never
/// installed. The existence check is injected, so the rule is testable without
/// a filesystem and the real check appears in exactly one place.
class HostDetector {
  const HostDetector({
    required this.matrix,
    required this.resolver,
    required this.directoryExists,
  });

  final HostMatrix matrix;
  final PathResolver resolver;

  /// Whether an absolute directory exists.
  final bool Function(String path) directoryExists;

  /// Detected host ids, sorted.
  ///
  /// A host is detected when its **marker** — its config root — is present, not
  /// when its skills directory is. A tool that is installed but has never been
  /// given a skill still reads its skills directory, and warning about it is
  /// correct; creating that directory to find out is not.
  Set<String> detect() => {
    for (final id in matrix.hostIds)
      if (_isInstalled(id)) id,
  };

  bool _isInstalled(String id) {
    final marker = matrix.host(id).marker;
    if (marker.isEmpty) return false;
    final path = resolver.expand(marker);
    return path != null && directoryExists(path);
  }
}
