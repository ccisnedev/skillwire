/// Entry point for the `skillwire` executable, aliased `sw`.
///
/// A thin shim: everything testable lives behind [runSkillwire], so nothing is
/// exercised through a process that could not be exercised in memory.
library;

import 'dart:io';

import 'package:skillwire_cli/skillwire_cli.dart';

Future<void> main(List<String> args) async {
  exit(await runSkillwire(args));
}
