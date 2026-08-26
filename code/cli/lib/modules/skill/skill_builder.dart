/// Registers the `skill` module — the five routes of PRD 12.2.
///
/// R12.1: the module is named `skill`, singular, in every consumer. `macss` and
/// `inquiry` mount this same module, and two modules differing by a single `s`
/// are prohibited.
library;

import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:skillwire/skillwire.dart';

import '../../src/catalogue.dart';
import '../../src/workspace.dart';
import '../../src/errors.dart';
import 'commands/deploy.dart';
import 'commands/inspect.dart';
import 'commands/list.dart';

/// Mount the module.
///
/// Two Commands and three Queries. The split is the SDK's: a Query reads and
/// answers and rejects `--plan`/`--apply`; a Command changes something and must
/// say what it would change first (R12.4).
///
/// Every route passes `params:` — `const []` at minimum. A Query registered
/// with `params: null` silently accepts `--plan`, because the SDK short-circuits
/// its own argument check when a command declares no contract.
void buildSkillModule(
  ModuleBuilder m, {
  required Workspace workspace,
  required Catalogue catalogue,
}) {
  m.query<SkillListInput, SkillListOutput>(
    'list',
    (req) => translating(() => SkillListCommand(
      SkillListInput.fromCliRequest(req, catalogue),
      workspace: workspace,
      catalogue: catalogue,
    )),
    description: 'Catalogue and status in one table, with what else can see it',
    params: SkillListInput.params,
  );

  m.command<SkillChangeInput, SkillChangeOutput>(
    'deploy',
    (req) => translating(() => SkillChangeCommand(
      SkillChangeInput.fromCliRequest(req, catalogue),
      workspace: workspace,
      catalogue: catalogue,
      operation: Operation.deploy,
    )),
    description: 'Reconcile a host toward the skills this release ships',
    params: SkillChangeInput.params,
  );

  m.command<SkillChangeInput, SkillChangeOutput>(
    'remove',
    (req) => translating(() => SkillChangeCommand(
      SkillChangeInput.fromCliRequest(req, catalogue),
      workspace: workspace,
      catalogue: catalogue,
      operation: Operation.remove,
    )),
    description: 'Reconcile a host away from them, touching only what this '
        'consumer deployed',
    params: SkillChangeInput.params,
  );

  m.query<SkillDoctorInput, SkillDoctorOutput>(
    'doctor',
    (req) => SkillDoctorCommand(
      SkillDoctorInput.fromCliRequest(req),
      workspace: workspace,
    ),
    description: 'Report what is deployed, who owns it, and what has drifted',
    params: SkillDoctorInput.params,
  );

  m.query<SkillValidateInput, SkillValidateOutput>(
    'validate',
    (req) => SkillValidateCommand(
      SkillValidateInput.fromCliRequest(req),
      catalogue: catalogue,
    ),
    description: 'Check this release\'s skills against the Agent Skills '
        'specification',
    params: SkillValidateInput.params,
  );
}
