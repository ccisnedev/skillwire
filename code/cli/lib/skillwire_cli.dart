/// Public API for the `skillwire` CLI.
///
/// [runSkillwire] is the single entry point — called by `bin/main.dart` and by
/// tests, so nothing is exercised through a process that could not be exercised
/// in memory.
library;

import 'dart:io' as io;

import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:skillwire/skillwire.dart';

import 'package:datajack/datajack.dart';

import 'modules/skill/version.dart';

/// The name this CLI writes into every ledger row it creates, and the name the
/// other two consumers see in a `block` when they meet one of its artifacts.
const consumerName = 'skillwire_cli';

/// The SDK routes every help request itself. Only `--version` needs
/// normalising, since it has no version convention of its own.
List<String> normaliseArgs(List<String> args) {
  if (args.length == 1 && (args.first == '--version' || args.first == '-v')) {
    return const ['version'];
  }
  return args;
}

/// Configure the CLI, register the module, and dispatch [args].
///
/// Returns a process exit code.
Future<int> runSkillwire(
  List<String> args, {
  io.IOSink? stdout,
  io.IOSink? stderr,
  Workspace? workspace,
  Catalogue? catalogue,
}) async {
  final ws = workspace ?? Workspace.detect();
  final cat = catalogue ??
      Catalogue.read(
        ws.assetsRoot,
        validator: SkillValidator(reservedNames: ws.matrix.reservedNames),
      );

  final cli = ModularCli();

  // R12.1 — the module is `skill`, singular, in every consumer. Two modules
  // differing by a single `s` are prohibited, and this CLI is the reference for
  // the other two.
  cli.module(
    'skill',
    (m) => buildSkillModule(
      m,
      consumer: consumerName,
      workspace: ws,
      catalogue: cat,
    ),
  );
  cli.module('', (m) => buildVersionRoute(m));

  return cli.run(
    normaliseArgs(args),
    stdout: stdout ?? io.stdout,
    stderr: stderr ?? io.stderr,
  );
}
