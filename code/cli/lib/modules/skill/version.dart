/// The `version` route. Registered on the empty module so it is `skillwire
/// version` rather than `skillwire skill version`.
library;

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';

/// Kept in step with `pubspec.yaml` by `version_test.dart`, because a version a
/// binary reports that its package does not carry is worse than none.
const skillwireCliVersion = '0.1.0';

class VersionInput extends Input {
  VersionInput();
  factory VersionInput.fromCliRequest(CliRequest req) => VersionInput();
  static const List<CliParam> params = [];
  @override
  List<CliParam> get schemaFields => params;
  @override
  Map<String, dynamic> toJson() => const {};
}

class VersionOutput extends Output {
  VersionOutput(this.version);
  final String version;
  @override
  Map<String, dynamic> toJson() => {'version': version};
  @override
  int get exitCode => ExitCode.ok;
  @override
  String? toText() => 'skillwire $version';
}

class VersionCommand implements Query<VersionInput, VersionOutput> {
  VersionCommand(this.input);
  @override
  final VersionInput input;
  @override
  String? validate() => null;
  @override
  Future<VersionOutput> execute() async => VersionOutput(skillwireCliVersion);
}

void buildVersionRoute(ModuleBuilder m) {
  m.query<VersionInput, VersionOutput>(
    'version',
    (req) => VersionCommand(VersionInput.fromCliRequest(req)),
    description: 'Print the version of this CLI',
    params: VersionInput.params,
  );
}
