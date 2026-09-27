/// Registers the `skill` module — the five routes of PRD 12.2.
///
/// R12.1: the module is named `skill`, singular, in every consumer. `macss` and
/// `inquiry` mount this same module, and two modules differing by a single `s`
/// are prohibited.
library;

import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:skillwire/skillwire.dart';

import 'errors.dart';
import 'commands/deploy.dart';
import 'commands/inspect.dart';
import 'commands/list.dart';

/// Mount the module.
///
/// Two Commands and three Queries. The split is the SDK's: a Query reads and
/// answers and rejects `--plan`/`--apply`; a Command changes something and must
/// say what it would change first (R12.4).
///
/// Every route passes `contract:` explicitly — `CliContract.none` at minimum,
/// since the SDK requires one rather than defaulting to it silently.
/// [consumer] is the CLI on whose behalf this module acts. It is written into
/// every ledger row the module creates, and it is the only thing that makes PRD
/// 10.2 state 5 — "deployed by a different consumer" — answerable for the
/// others. A parameter rather than a constant is what lets one module serve
/// `skillwire_cli`, `macss` and `inquiry` without a fork.
void buildSkillModule(
  ModuleBuilder m, {
  required String consumer,
  required Workspace workspace,
  required Catalogue catalogue,
}) {
  m.query<SkillListInput, SkillListOutput>(
    'list',
    (req) => translating(
      () => SkillListCommand(
        SkillListInput.fromCliRequest(req, catalogue),
        consumer: consumer,
        workspace: workspace,
        catalogue: catalogue,
      ),
    ),
    description: 'Catalogue and status in one table, with what else can see it',
    globals: true,
    contract: SkillListInput.contract,
  );

  m.command<SkillChangeInput, SkillChangeOutput>(
    'deploy',
    (req) => translating(
      () => SkillChangeCommand(
        SkillChangeInput.fromCliRequest(req, catalogue),
        consumer: consumer,
        workspace: workspace,
        catalogue: catalogue,
        operation: Operation.deploy,
      ),
    ),
    description: 'Reconcile a host toward the skills this release ships',
    globals: true,
    contract: SkillChangeInput.contract,
  );

  m.command<SkillChangeInput, SkillChangeOutput>(
    'remove',
    (req) => translating(
      () => SkillChangeCommand(
        SkillChangeInput.fromCliRequest(req, catalogue),
        consumer: consumer,
        workspace: workspace,
        catalogue: catalogue,
        operation: Operation.remove,
      ),
    ),
    description:
        'Reconcile a host away from them, touching only what this '
        'consumer deployed',
    globals: true,
    contract: SkillChangeInput.contract,
  );

  m.query<SkillDoctorInput, SkillDoctorOutput>(
    'doctor',
    (req) => SkillDoctorCommand(
      SkillDoctorInput.fromCliRequest(req),
      consumer: consumer,
      workspace: workspace,
    ),
    description: 'Report what is deployed, who owns it, and what has drifted',
    globals: true,
    contract: SkillDoctorInput.contract,
  );

  m.query<SkillValidateInput, SkillValidateOutput>(
    'validate',
    (req) => SkillValidateCommand(
      SkillValidateInput.fromCliRequest(req),
      catalogue: catalogue,
    ),
    description:
        'Check this release\'s skills against the Agent Skills '
        'specification',
    globals: true,
    contract: SkillValidateInput.contract,
  );
}
