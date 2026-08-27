/// Where a deployment lands.
///
/// Two, and only two. Codex also reads a machine-wide `/etc/codex/skills`
/// (PRD 6.6), which is neither: modelling it would put a third scope in the
/// unit tuple, the ledger key and every route's parameters. R6.10 makes it a
/// non-destination instead.
enum Scope {
  /// User-level. `~/.claude/skills/`, `$CODEX_HOME/skills/`, and so on.
  global,

  /// Repository-level, resolved to the repository **root** and nowhere else
  /// (R6.8), even though Codex and Antigravity also search intermediate
  /// directories on the way up.
  repo;

  String get token => switch (this) { Scope.global => 'global', Scope.repo => 'repo' };

  static Scope fromToken(String token) => switch (token) {
    'global' => Scope.global,
    'repo' => Scope.repo,
    _ => throw ArgumentError.value(token, 'token', 'not a Scope'),
  };
}
