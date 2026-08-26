import 'domain/scope.dart';

/// Everything this package throws, rooted in one sealed type (R12.7).
///
/// Sealed so that a consumer's `switch` over it is exhaustive and the analyser
/// proves it: adding a member breaks every consumer at compile time instead of
/// slipping past a string match at runtime. That is the whole point — a
/// consumer must never have to read [message] to decide what happened.
///
/// [code] is the stable, machine-readable name. [message] is for a human and
/// may be reworded freely; [code] may not.
sealed class SkillwireError implements Exception {
  const SkillwireError();

  /// Stable snake_case identity. Part of the contract; never reword it.
  String get code;

  /// What went wrong, in a sentence a user can act on.
  String get message;

  @override
  String toString() => 'SkillwireError($code): $message';
}

/// A host id that is not in the matrix.
class UnknownHost extends SkillwireError {
  const UnknownHost(this.host);

  final String host;

  @override
  String get code => 'unknown_host';

  @override
  String get message => 'No host named "$host" in the matrix.';
}

/// A matrix row without provenance in PRD 14.1 was asked to resolve (R6.4).
///
/// Refusing is the conforming answer. Non-negotiable rule 5: never present an
/// unverified path as a fact — and a path returned to a caller who will write
/// to it has been presented as a fact.
class UnverifiedHostPath extends SkillwireError {
  const UnverifiedHostPath({required this.host, required this.scope});

  final String host;
  final Scope scope;

  @override
  String get code => 'unverified_host_path';

  @override
  String get message =>
      'The $host path at ${scope.token} scope carries no provenance in PRD 14.1, '
      'so it cannot be resolved (R6.4, R14.1). Verify it against the host itself '
      'and record the source and date before deploying.';
}

/// A path a host reads but this package will never write to — `/etc/codex/skills`
/// is machine-wide, which is neither of the two scopes this project models
/// (R6.10).
class NotADestination extends SkillwireError {
  const NotADestination({required this.path, required this.reason});

  final String path;
  final String reason;

  @override
  String get code => 'not_a_destination';

  @override
  String get message => '$path is never a deployment destination: $reason.';
}

/// A required parameter was omitted (R12.2). There is no implicit "all hosts"
/// and no default scope; omission is an error, never a default.
class MissingParameter extends SkillwireError {
  const MissingParameter(this.parameter);

  final String parameter;

  @override
  String get code => 'missing_parameter';

  @override
  String get message =>
      '$parameter is required and has no default (R12.2).';
}

/// `--scope=repo` outside a repository (R12.3). It MUST NOT fall back to
/// `global`: silently deploying to a user's home when they asked for a project
/// is the kind of surprise rule 2 exists to prevent.
class RepoScopeOutsideRepository extends SkillwireError {
  const RepoScopeOutsideRepository(this.startedFrom);

  final String startedFrom;

  @override
  String get code => 'repo_scope_outside_repository';

  @override
  String get message =>
      'No repository root found from $startedFrom, so --scope=repo cannot '
      'resolve. It does not fall back to global (R12.3).';
}

/// The ledger exists but cannot be read.
///
/// Never treated as an empty ledger: that would reclassify every managed unit
/// into PRD 10.2 state 6 and, under `--force`, invite adopting or overwriting
/// artifacts whose real ownership was merely unreadable.
class LedgerUnreadable extends SkillwireError {
  const LedgerUnreadable({required this.path, required this.cause});

  final String path;
  final String cause;

  @override
  String get code => 'ledger_unreadable';

  @override
  String get message =>
      'The ledger at $path could not be read ($cause). Refusing to treat it as '
      'empty: every deployed unit would look unowned.';
}

/// An artifact does not conform to the Agent Skills specification (PRD 13.1).
///
/// Carries every finding rather than the first, because a user fixing one fault
/// at a time across four runs is a worse experience than fixing four at once.
class SkillInvalid extends SkillwireError {
  const SkillInvalid({required this.artifact, required this.findings});

  final String artifact;
  final List<String> findings;

  @override
  String get code => 'skill_invalid';

  @override
  String get message =>
      '$artifact does not conform to the Agent Skills specification:\n'
      '${findings.map((f) => '  - $f').join('\n')}';
}
