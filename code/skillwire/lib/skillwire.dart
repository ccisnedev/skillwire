/// Deploys agent skills and subagents into AI coding hosts, resolving the path
/// and file format each host expects.
///
/// The package **produces** steps and never runs them (R12.9). It depends on
/// `preview_executor` for the `Step` / `Preview` / `Outcome` vocabulary and
/// never on `modular_cli_sdk`, which re-exports those same types to consumers
/// (R12.8) — so a `Step` built here is the type a consumer's `Command.steps()`
/// returns, with no adapter between them.
library;

export 'src/hash/content_hash.dart' show contentHash;

export 'src/diagnose/diagnosis.dart'
    show
        ClaimedUnit,
        Diagnosis,
        DuplicateArtifact,
        FoundArtifact,
        HostScope,
        LedgerClaim,
        UnmanagedArtifact,
        diagnose;

export 'src/hosts/host_matrix.dart'
    show HostDirectory, HostEntry, HostMatrix, Provenance, VisibilityEdge;

export 'src/hosts/resolution.dart' show HostDetector, PathResolver;

export 'src/validate/skill_validator.dart'
    show Finding, SkillFrontmatter, SkillValidator, ValidationResult;

export 'src/io/filesystem.dart'
    show FilesystemSink, LedgerFile, observe, readTree;
export 'src/ledger/ledger.dart' show Ledger, LedgerRow, SourceType;

export 'src/reconcile/reconciler.dart' show Plan, reconcile;
export 'src/reconcile/state.dart'
    show Desired, LedgerRecord, Observed, Operation, Verb;
export 'src/reconcile/steps.dart'
    show ApplyUnit, BlockedUnit, DeploymentSink, ReconcileStep, RetireUnit;

export 'src/errors.dart'
    show
        LedgerUnreadable,
        MissingParameter,
        NotADestination,
        RepoScopeOutsideRepository,
        SkillInvalid,
        SkillwireError,
        UnknownHost,
        UnverifiedHostPath;

export 'src/domain/kind.dart' show Kind;
export 'src/domain/scope.dart' show Scope;
export 'src/domain/unit.dart' show Unit;
