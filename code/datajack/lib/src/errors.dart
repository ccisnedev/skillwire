/// Turning a package error into something the SDK understands.
library;

import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:skillwire/skillwire.dart';

/// Run [build], translating any [SkillwireError] into a [CommandException].
///
/// Command factories read the request, and reading the request is where R12.2
/// and R12.3 are enforced — so a factory throws. The SDK understands
/// `CommandException` and nothing else; without this an omitted `--host` would
/// reach the user as an unhandled exception and a stack trace, which is a
/// usage error reported as a crash.
T translating<T>(T Function() build) {
  try {
    return build();
  } on SkillwireError catch (e) {
    throw asCommandException(e);
  }
}

/// Map a package error onto the SDK's exit codes.
///
/// A `switch` over a sealed type, so adding an error breaks this function at
/// compile time rather than falling through to a generic code. That is the
/// whole reason R12.7 requires the hierarchy to be sealed.
CommandException asCommandException(SkillwireError e) => CommandException(
  code: e.code,
  message: e.message,
  exitCode: switch (e) {
    UnknownHost() => ExitCode.invalidUsage,
    MissingParameter() => ExitCode.invalidUsage,
    RepoScopeOutsideRepository() => ExitCode.invalidUsage,
    UnverifiedHostPath() => ExitCode.validationFailed,
    NotADestination() => ExitCode.validationFailed,
    SkillInvalid() => ExitCode.validationFailed,
    LedgerUnreadable() => ExitCode.conflict,
  },
);
