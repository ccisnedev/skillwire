import 'dart:io' as io;

import 'package:path/path.dart' as p;
import 'package:skillwire/skillwire.dart';

/// Everything the CLI needs to know about the machine it is running on,
/// gathered once so that no command reads the environment for itself.
///
/// This is the "one read before" of R10.4 at the CLI's own level: commands
/// receive a workspace and never call `Platform` or `Directory` directly, which
/// is what lets a test pose a whole machine without one.
class Workspace {
  Workspace({
    required this.home,
    required this.environment,
    required this.repositoryRoot,
    required this.assetsRoot,
    required this.matrix,
    required this.ledgerFile,
    bool Function(String)? directoryExists,
  }) : _directoryExists = directoryExists ?? _realDirectoryExists;

  /// Read the real machine.
  factory Workspace.detect({
    String? workingDirectory,
    String? assetsRoot,
    Map<String, String>? environment,
  }) {
    final env = environment ?? io.Platform.environment;
    final home = env['HOME'] ?? env['USERPROFILE'] ?? '';
    final cwd = workingDirectory ?? io.Directory.current.path;
    return Workspace(
      home: home,
      environment: env,
      repositoryRoot: findRepositoryRoot(cwd),
      assetsRoot: assetsRoot ?? defaultAssetsRoot(),
      matrix: HostMatrix.builtIn(),
      ledgerFile: LedgerFile.resolve(home: home, environment: env),
    );
  }

  final String home;
  final Map<String, String> environment;

  /// Null outside a repository, which makes `--scope=repo` throw rather than
  /// fall back to `global` (R12.3).
  final String? repositoryRoot;

  /// Where this release's `assets/skills/modules/` lives.
  final String assetsRoot;

  final HostMatrix matrix;
  final LedgerFile ledgerFile;

  final bool Function(String) _directoryExists;

  static bool _realDirectoryExists(String path) =>
      io.Directory(path).existsSync();

  PathResolver get resolver => PathResolver(
    home: home,
    environment: environment,
    repositoryRoot: repositoryRoot,
  );

  /// Hosts present on this machine. R7.4 lets only these be named in an
  /// annotation, so a warning never mentions a tool the user does not have.
  Set<String> get detectedHosts => HostDetector(
    matrix: matrix,
    resolver: resolver,
    directoryExists: _directoryExists,
  ).detect();

  /// The repository root, walking up from [from] until a `.git` appears.
  ///
  /// R6.8 resolves `repo` scope to the root and nowhere else, even though Codex
  /// and Antigravity also search intermediate directories on the way up and
  /// Claude Code searches downward. Deploying into an intermediate directory
  /// would make what a host loads depend on where the user was standing, which
  /// defeats G4.
  static String? findRepositoryRoot(String from) {
    var dir = io.Directory(p.absolute(from));
    while (true) {
      if (io.Directory(p.join(dir.path, '.git')).existsSync() ||
          io.File(p.join(dir.path, '.git')).existsSync()) {
        return dir.path;
      }
      final parent = dir.parent;
      if (parent.path == dir.path) return null;
      dir = parent;
    }
  }

  /// Where the running executable's assets are.
  ///
  /// Two layouts, because a `modular_cli_sdk` CLI runs both compiled and from
  /// source with `dart run`, and the working copy is the asset in the second
  /// case — which is why the PRD rules a "dev mode" out of scope.
  static String defaultAssetsRoot() {
    final beside = p.join(
      p.dirname(p.dirname(io.Platform.resolvedExecutable)),
      'assets',
    );
    if (io.Directory(beside).existsSync()) return beside;
    return p.join(p.current, 'assets');
  }
}
