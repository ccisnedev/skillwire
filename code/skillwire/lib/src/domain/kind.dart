/// The type of an artifact deployed into a host.
///
/// Both members exist from P1 although only [skill] is implemented, because
/// R15.1 requires `kind` in the resolver signature and the ledger key from the
/// start: adding it later would change the ledger key, the reconciliation
/// signature and the manifest schema in one move.
enum Kind {
  /// A directory containing `SKILL.md`, per the Agent Skills specification.
  skill,

  /// A scoped agent with its own context. Path *and* format differ per host,
  /// which is why P6 is gated on PRD Q1 and Q2.
  subagent;

  /// The token this kind contributes to a [Unit] key. Never derive it from
  /// [name] at a call site — the ledger is on disk and must not move when a
  /// member is renamed in Dart.
  String get token => switch (this) { Kind.skill => 'skill', Kind.subagent => 'subagent' };

  static Kind fromToken(String token) => switch (token) {
    'skill' => Kind.skill,
    'subagent' => Kind.subagent,
    _ => throw ArgumentError.value(token, 'token', 'not a Kind'),
  };
}
