/// The command-line surface of the `skillwire` package.
///
/// In Shadowrun a *datajack* is the port through which a person connects to a
/// device. The wire moves the skills; this is where a human plugs in to govern
/// it — which is what someone typing `skill deploy --host claude` is doing.
///
/// It is a separate package because it is irreducibly a command-line surface,
/// and the domain is not. It declares `--host` and `--scope`, maps failures onto
/// exit codes, and renders an aligned table for a terminal. None of that
/// survives a move to another transport, and none of it belongs in a library
/// about reconciling directories. See `docs/adr/0005`.
///
/// Mount it in one line:
///
/// ```dart
/// cli.module('skill', (m) => buildSkillModule(
///   m,
///   consumer: 'macss',
///   workspace: workspace,
///   catalogue: catalogue,
/// ));
/// ```
library;

export 'src/commands/deploy.dart'
    show SkillChangeCommand, SkillChangeInput, SkillChangeOutput;
export 'src/commands/inspect.dart'
    show
        SkillDoctorCommand,
        SkillDoctorInput,
        SkillDoctorOutput,
        SkillValidateCommand,
        SkillValidateInput,
        SkillValidateOutput;
export 'src/commands/list.dart'
    show SkillListCommand, SkillListInput, SkillListOutput, SkillListRow;
export 'src/errors.dart' show asCommandException, translating;
export 'src/selection_params.dart' show SelectionParams;
export 'src/skill_builder.dart' show buildSkillModule;
