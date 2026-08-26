import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:skillwire/skillwire.dart';

import '../../../src/catalogue.dart';
import '../../../src/planner.dart';
import '../../../src/workspace.dart';
import '../selection_params.dart';

class SkillChangeInput extends Input {
  SkillChangeInput({
    required this.selection,
    required this.force,
    required this.applying,
  });

  factory SkillChangeInput.fromCliRequest(CliRequest req, Catalogue catalogue) =>
      SkillChangeInput(
        selection: SelectionParams.read(req, catalogue),
        force: req.flagBool(SelectionParams.forceFlag),
        applying: req.flagBool('apply'),
      );

  final Selection selection;

  /// R10.2 — no other flag implies it.
  final bool force;

  /// Whether this run intends to change anything.
  ///
  /// Read here rather than inferred, because R10.1's refusal belongs to
  /// `--apply` alone. Under `--plan` the blocks must be *rendered*: a user who
  /// cannot see what is in the way cannot decide what to do about it, and
  /// refusing to show them is the opposite of what a plan is for.
  final bool applying;

  static final List<CliParam> params = SelectionParams.withForce;

  @override
  List<CliParam> get schemaFields => params;

  @override
  Map<String, dynamic> toJson() => {
    'hosts': selection.hosts,
    'scope': selection.scope.token,
    'skills': [for (final s in selection.skills) s.name],
    'force': force,
    'applying': applying,
  };
}

class SkillChangeOutput extends Output {
  SkillChangeOutput({required this.execution, required this.blocked});

  final Execution execution;
  final List<String> blocked;

  @override
  Map<String, dynamic> toJson() => {
    'outcomes': [
      for (final o in execution.outcomes) {'verb': o.verb, 'target': o.target},
    ],
    'blocked': blocked,
  };

  /// A run whose plan carried a block exits non-zero even when the applicable
  /// units succeeded. `--force` lets the plan proceed; it does not make the
  /// blocks stop mattering.
  @override
  int get exitCode => blocked.isEmpty ? ExitCode.ok : ExitCode.conflict;

  @override
  String? toText() {
    if (blocked.isEmpty) return null;
    return 'Blocked, and left untouched:\n'
        '${blocked.map((b) => '  $b').join('\n')}';
  }
}

/// `skill deploy` and `skill remove`.
///
/// One class for both because they are the same operation in two directions:
/// reconcile toward a desired state, or away from it. The verbs differ; the
/// read, the pure decision and the write do not.
class SkillChangeCommand implements Command<SkillChangeInput, SkillChangeOutput> {
  SkillChangeCommand(
    this.input, {
    required this.workspace,
    required this.catalogue,
    required this.operation,
  });

  @override
  final SkillChangeInput input;

  final Workspace workspace;
  final Catalogue catalogue;
  final Operation operation;

  Plan? _plan;

  @override
  String? validate() {
    // R13.2 — names are globally unique across all modules. Deployment is flat,
    // so two modules shipping one name would deploy one over the other.
    final duplicates = catalogue.duplicateNames;
    if (duplicates.isNotEmpty) {
      return 'These artifact names appear in more than one module, and '
          'deployment is flat (R13.2): ${duplicates.join(', ')}.';
    }

    // Nothing invalid reaches a host. skill validate exists to be run before
    // this, but a release that shipped a broken skill should not be able to
    // deploy it by accident.
    final invalid = [
      for (final s in input.selection.skills)
        if (!s.isValid) s.name,
    ];
    if (invalid.isNotEmpty) {
      return 'These skills do not conform to the Agent Skills specification: '
          '${invalid.join(', ')}. Run `skillwire skill validate` for detail.';
    }

    for (final host in input.selection.hosts) {
      if (!workspace.matrix.hosts.containsKey(host)) {
        return 'No host named "$host". Known hosts: '
            '${workspace.matrix.hostIds.join(', ')}.';
      }
    }
    return null;
  }

  @override
  Future<List<Step>> steps() async {
    final planner = Planner(workspace: workspace, catalogue: catalogue);
    final ledger = workspace.ledgerFile.read();
    final desired = planner.desired(input.selection);

    _plan = reconcile(
      operation: operation,
      observed: planner.observe(desired, ledger),
      desired: desired,
      actingConsumer: actingConsumer,
      force: input.force,
      annotations: planner.annotations(
        desired,
        input.selection,
        removing: operation == Operation.remove,
      ),
      sink: FilesystemSink(
        ledgerFile: workspace.ledgerFile,
        actingConsumer: actingConsumer,
        sourceType: SourceType.local,
        sourceReference: workspace.assetsRoot,
        artifactVersions: catalogue.versions,
      ),
    );

    // R10.1 — a plan containing any block refuses --apply unless --force.
    //
    // Scoped to --apply on purpose. Under --plan the steps are returned and
    // rendered, blocks and all, because the whole point of a plan is to show
    // what is in the way. A blocked step performs nothing even if it is run.
    if (input.applying && !_plan!.isApplicable) {
      throw CommandException(
        code: 'plan_contains_blocks',
        message:
            'This plan would leave ${_plan!.blocked.length} unit(s) untouched, and '
            'refuses to apply. Read the blocks above. Pass --force to apply the '
            'rest; --force never overwrites a blocked unit, and on a destination '
            'no consumer deployed whose contents already match, it adopts it '
            'into the ledger without writing (R10.6).',
        exitCode: ExitCode.conflict,
      );
    }

    return _plan!.steps;
  }

  @override
  SkillChangeOutput describe(Execution execution) => SkillChangeOutput(
    execution: execution,
    blocked: [
      for (final b in _plan?.blocked ?? const <BlockedUnit>[])
        '${b.unit.artifact} -> ${b.destination}: ${b.reason}',
    ],
  );
}
