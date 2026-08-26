import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:skillwire/skillwire.dart';

import '../../src/catalogue.dart';
import '../../src/planner.dart';

/// The parameter contract every route in this module shares, and the rules that
/// make R12.2 true rather than aspirational.
///
/// `--host` is declared as a **comma-separated string** rather than a repeatable
/// option. PRD 12.3 calls it repeatable, but `modular_cli_sdk` cannot express
/// that: `cli_router` keeps flags in a map keyed by name, so a second `--host`
/// silently overwrites the first, and the SDK will not let a command declare a
/// facet the runtime cannot honour. A comma-separated list keeps the intent —
/// name several hosts in one invocation — and is the only spelling that cannot
/// lose one of them without saying so.
abstract final class SelectionParams {
  static const hostsFlag = 'host';
  static const scopeFlag = 'scope';
  static const skillFlag = 'skill';
  static const moduleFlag = 'module';
  static const allFlag = 'all';
  static const forceFlag = 'force';

  static final List<CliParam> shared = [
    CliParam.string(
      hostsFlag,
      description:
          'Hosts to act on, comma-separated: claude,codex,antigravity,opencode,copilot. '
          'Required; there is no implicit "all hosts" (R12.2)',
    ),
    CliParam.string(
      scopeFlag,
      allowed: ['global', 'repo'],
      description: 'global (user-level) or repo (repository-level). Required; '
          'there is no default (R12.2)',
    ),
    CliParam.string(skillFlag, description: 'One artifact by name'),
    CliParam.string(moduleFlag, description: 'Every artifact in one module'),
    CliParam.boolean(allFlag, description: 'Every artifact this release ships'),
  ];

  static final List<CliParam> withForce = [
    ...shared,
    CliParam.boolean(
      forceFlag,
      description:
          'Let an apply proceed past a plan containing blocks, and adopt an '
          'unledgered destination whose contents already match (R10.6). It '
          'never lifts the block on a unit',
    ),
  ];

  /// Read a selection from a request, or throw the typed error that says which
  /// rule was broken.
  ///
  /// Every check here exists because R12.2 forbids a default. A missing `--host`
  /// could plausibly mean "every host I have installed", and that is exactly the
  /// guess this refuses to make.
  static Selection read(CliRequest req, Catalogue catalogue) {
    final hostsRaw = req.flagString(hostsFlag);
    if (hostsRaw == null || hostsRaw.trim().isEmpty) {
      throw const MissingParameter('--host');
    }
    final hosts = [
      for (final h in hostsRaw.split(','))
        if (h.trim().isNotEmpty) h.trim(),
    ];
    if (hosts.isEmpty) throw const MissingParameter('--host');

    final scopeRaw = req.flagString(scopeFlag);
    if (scopeRaw == null || scopeRaw.isEmpty) {
      throw const MissingParameter('--scope');
    }

    return Selection(
      hosts: hosts,
      scope: Scope.fromToken(scopeRaw),
      skills: _artifacts(req, catalogue),
    );
  }

  /// Exactly one of `--skill`, `--module` or `--all` (PRD 12.3).
  static List<ShippedSkill> _artifacts(CliRequest req, Catalogue catalogue) {
    final skill = req.flagString(skillFlag);
    final module = req.flagString(moduleFlag);
    final all = req.flagBool(allFlag);

    final given = [
      if (skill != null && skill.isNotEmpty) skillFlag,
      if (module != null && module.isNotEmpty) moduleFlag,
      if (all) allFlag,
    ];
    if (given.isEmpty) throw const MissingParameter('--skill, --module or --all');
    if (given.length > 1) {
      throw CommandException(
        code: 'ambiguous_selection',
        message:
            'Give exactly one of --skill, --module or --all; got ${given.map((g) => '--$g').join(' and ')}.',
        exitCode: ExitCode.invalidUsage,
      );
    }

    if (all) return catalogue.skills;
    if (module != null && module.isNotEmpty) {
      final found = catalogue.inModule(module);
      if (found.isEmpty) {
        throw CommandException(
          code: 'unknown_module',
          message: 'No module named "$module". This release ships: '
              '${catalogue.modules.join(', ')}.',
          exitCode: ExitCode.notFound,
        );
      }
      return found;
    }
    final found = catalogue.byName(skill!);
    if (found == null) {
      throw CommandException(
        code: 'unknown_skill',
        message: 'No skill named "$skill". This release ships: '
            '${catalogue.names.join(', ')}.',
        exitCode: ExitCode.notFound,
      );
    }
    return [found];
  }
}
