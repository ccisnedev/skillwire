import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:skillwire/skillwire.dart';

import '../../../src/catalogue.dart';
import '../../../src/planner.dart';
import '../../../src/workspace.dart';
import '../selection_params.dart';

class SkillListInput extends Input {
  SkillListInput({required this.selection});

  factory SkillListInput.fromCliRequest(CliRequest req, Catalogue catalogue) =>
      SkillListInput(selection: SelectionParams.read(req, catalogue));

  final Selection selection;

  static final List<CliParam> params = SelectionParams.shared;

  @override
  List<CliParam> get schemaFields => params;

  @override
  Map<String, dynamic> toJson() => {
    'hosts': selection.hosts,
    'scope': selection.scope.token,
  };
}

/// One line of the table PRD 12.2 specifies:
/// name · version · module · kind · host · scope · status · also visible from.
class SkillListRow {
  const SkillListRow({
    required this.name,
    required this.version,
    required this.module,
    required this.kind,
    required this.host,
    required this.scope,
    required this.status,
    required this.alsoVisibleFrom,
  });

  final String name;
  final String version;
  final String module;
  final String kind;
  final String host;
  final String scope;

  /// The verb this unit would resolve to right now, which is what makes the
  /// table a status rather than an inventory.
  final String status;

  /// Section 7 made visible: detected hosts that read the destination without
  /// having been targeted (R7.9).
  final String alsoVisibleFrom;

  Map<String, dynamic> toJson() => {
    'name': name,
    'version': version,
    'module': module,
    'kind': kind,
    'host': host,
    'scope': scope,
    'status': status,
    'alsoVisibleFrom': alsoVisibleFrom,
  };

  List<String> get cells =>
      [name, version, module, kind, host, scope, status, alsoVisibleFrom];
}

class SkillListOutput extends Output {
  SkillListOutput({required this.rows});

  final List<SkillListRow> rows;

  @override
  Map<String, dynamic> toJson() => {'rows': [for (final r in rows) r.toJson()]};

  @override
  int get exitCode => ExitCode.ok;

  @override
  String? toText() {
    if (rows.isEmpty) return 'Nothing selected.';
    const headers = [
      'name',
      'version',
      'module',
      'kind',
      'host',
      'scope',
      'status',
      'also visible from',
    ];
    final all = [headers, for (final r in rows) r.cells];
    final widths = [
      for (var i = 0; i < headers.length; i++)
        all.map((row) => row[i].length).reduce((a, b) => a > b ? a : b),
    ];
    String line(List<String> cells) => [
      for (var i = 0; i < cells.length; i++) cells[i].padRight(widths[i]),
    ].join('  ').trimRight();

    return [
      line(headers),
      line([for (final w in widths) '-' * w]),
      for (final r in rows) line(r.cells),
    ].join('\n');
  }
}

/// `skill list` — catalogue and status in one table (PRD 12.2).
///
/// A Query: it reads and answers, and rejects `--plan` / `--apply`. It builds a
/// plan only to read the previews, which is why it hands the reconciler no sink.
class SkillListCommand implements Query<SkillListInput, SkillListOutput> {
  SkillListCommand(this.input, {required this.workspace, required this.catalogue});

  @override
  final SkillListInput input;

  final Workspace workspace;
  final Catalogue catalogue;

  @override
  String? validate() => null;

  @override
  Future<SkillListOutput> execute() async {
    final planner = Planner(workspace: workspace, catalogue: catalogue);
    final ledger = workspace.ledgerFile.read();
    final desired = planner.desired(input.selection);
    final annotations = planner.annotations(
      desired,
      input.selection,
      removing: false,
    );

    final plan = reconcile(
      operation: Operation.deploy,
      observed: planner.observe(desired, ledger),
      desired: desired,
      actingConsumer: actingConsumer,
      annotations: annotations,
    );

    final byUnit = {
      for (final s in plan.steps.whereType<ReconcileStep>()) s.unit: s,
    };

    return SkillListOutput(
      rows: [
        for (final unit in desired.keys.toList()
          ..sort((a, b) => a.key.compareTo(b.key)))
          SkillListRow(
            name: unit.artifact,
            version: catalogue.byName(unit.artifact)?.version ?? '',
            module: catalogue.byName(unit.artifact)?.module ?? '',
            kind: unit.kind.token,
            host: unit.host,
            scope: unit.scope.token,
            status: byUnit[unit]?.verb ?? '',
            alsoVisibleFrom: _visibility(annotations[unit]),
          ),
      ],
    );
  }

  /// The eighth column carries only the cross-host part of the annotation set;
  /// the rest is prose that belongs in a plan's detail, not in a table cell.
  String _visibility(List<String>? notes) {
    if (notes == null) return '';
    for (final n in notes) {
      if (n.startsWith('also visible from: ')) {
        return n.substring('also visible from: '.length);
      }
    }
    return '';
  }
}
