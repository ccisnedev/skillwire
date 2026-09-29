import 'dart:convert';
import 'dart:io';

import 'package:datajack/datajack.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;
import 'package:skillwire/skillwire.dart';
import 'package:test/test.dart';

/// cli_router 0.2.1's GNU permutation and modular_cli_sdk 0.8.1's
/// `environment` parameter on `ModularCli.run`, which is what lets a caller
/// choose that ordering without touching the real process environment.
///
/// None of the five routes `buildSkillModule` mounts (`deploy`, `remove`,
/// `list`, `doctor`, `validate`) takes a positional operand: every one of
/// them is flags only (`--host`, `--scope`, `--skill`, ...), so no route
/// this module declares combines an operand with an option. The closest
/// real command that does is the SDK's own built-in `help`, registered with
/// a trailing wildcard (`help *`) precisely so a focus word (`help skill`)
/// is a genuine operand; a global option such as `--quiet` written after it
/// is exactly the case cli_router 0.2.1 permutes ahead of the operand by
/// default, and rejects as `misplaced-option` under `POSIXLY_CORRECT`.
void main() {
  late Directory tmp;
  late String home;
  late String assetsRoot;
  late String sharedLedger;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('datajack_env_');
    home = p.join(tmp.path, 'home');
    sharedLedger = p.join(tmp.path, 'state', 'ledger.json');
    Directory(p.join(home, '.claude')).createSync(recursive: true);

    assetsRoot = p.join(tmp.path, 'assets');
    final skill = File(
      p.join(assetsRoot, 'skills', 'modules', 'core', 'legion', 'SKILL.md'),
    );
    skill.parent.createSync(recursive: true);
    skill.writeAsStringSync(
      '---\n'
      'name: legion\n'
      'description: A skill for testing. Use when running the test suite.\n'
      'license: MIT\n'
      'metadata:\n'
      '  version: "1.0.0"\n'
      '  skillwire-origin: test\n'
      '---\n\n# Body\n',
    );
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  Future<(int, String, String)> run(
    List<String> args, {
    Map<String, String>? environment,
  }) async {
    final out = StringBuffer();
    final err = StringBuffer();

    final workspace = Workspace(
      home: home,
      environment: {'HOME': home},
      repositoryRoot: null,
      assetsRoot: assetsRoot,
      matrix: HostMatrix.builtIn(),
      ledgerFile: LedgerFile(sharedLedger),
    );
    final catalogue = Catalogue.read(
      assetsRoot,
      validator: SkillValidator(reservedNames: workspace.matrix.reservedNames),
    );

    final cli = ModularCli(suggestionDistance: 2);
    cli.module(
      'skill',
      (m) => buildSkillModule(
        m,
        consumer: 'test',
        workspace: workspace,
        catalogue: catalogue,
      ),
    );

    final code = await cli.run(
      args,
      stdout: _BufferSink(out),
      stderr: _BufferSink(err),
      environment: environment,
    );
    return (code, out.toString(), err.toString());
  }

  group('cli_router 0.2.1 - option ordering honors POSIXLY_CORRECT', () {
    test(
      'the built-in help command accepts an option after its operand by '
      'default (GNU permutation)',
      () async {
        final (code, _, err) = await run([
          'help',
          '--json',
          'skill',
          '--quiet',
        ], environment: {});
        expect(code, 0);
        expect(err, isEmpty);
      },
    );

    test(
      'the same invocation is rejected as misplaced-option under '
      'POSIXLY_CORRECT',
      () async {
        final (code, _, err) = await run([
          'help',
          '--json',
          'skill',
          '--quiet',
        ], environment: {'POSIXLY_CORRECT': '1'});
        expect(code, isNot(0));
        final error =
            (jsonDecode(err) as Map<String, dynamic>)['error']
                as Map<String, dynamic>;
        expect(error['id'], 'misplaced-option');
      },
    );
  });
}

/// Collects CLI output so a test can read what a user would see.
class _BufferSink implements IOSink {
  _BufferSink(this._buffer);

  final StringBuffer _buffer;

  @override
  Encoding encoding = utf8;

  @override
  void write(Object? object) => _buffer.write(object);

  @override
  void writeln([Object? object = '']) => _buffer.writeln(object);

  @override
  void writeAll(Iterable objects, [String separator = '']) =>
      _buffer.writeAll(objects, separator);

  @override
  void writeCharCode(int charCode) => _buffer.writeCharCode(charCode);

  @override
  void add(List<int> data) => _buffer.write(utf8.decode(data));

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future addStream(Stream<List<int>> stream) async {}

  @override
  Future close() async {}

  @override
  Future get done async {}

  @override
  Future flush() async {}
}
