import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:skillwire/skillwire.dart';
import 'package:skillwire_cli/skillwire_cli.dart';
import 'package:test/test.dart';

/// The CLI end to end, driven in memory against a fabricated machine.
///
/// Nothing here shells out. `runSkillwire` is the entry point `bin/main.dart`
/// calls, so what these tests exercise is what a user runs.
void main() {
  late Directory tmp;
  late String home;
  late String assets;

  void writeSkill(
    String module,
    String name, {
    String version = '1.0.0',
    String? compatibility,
    String body = '# Body\n',
  }) {
    final f = File(p.join(assets, 'skills', 'modules', module, name, 'SKILL.md'));
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(
      '---\n'
      'name: $name\n'
      'description: A skill for testing. Use when running the test suite.\n'
      'license: MIT\n'
      '${compatibility == null ? '' : 'compatibility: $compatibility\n'}'
      'metadata:\n'
      '  version: "$version"\n'
      '  skillwire-origin: skillwire_cli\n'
      '---\n\n$body',
    );
  }

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('skillwire_cli_');
    home = p.join(tmp.path, 'home');
    assets = p.join(tmp.path, 'assets');

    // A machine with Claude Code and OpenCode installed and nothing else, so
    // R7.4 has something to be right about.
    for (final marker in ['.claude', p.join('.config', 'opencode')]) {
      Directory(p.join(home, marker)).createSync(recursive: true);
    }

    writeSkill('core', 'legion', version: '1.0.0');
    writeSkill('core', 'kritik', version: '2.1.0');
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  Workspace workspace() => Workspace(
    home: home,
    environment: {'HOME': home, 'SKILLWIRE_HOME': p.join(tmp.path, 'state')},
    repositoryRoot: p.join(tmp.path, 'repo'),
    assetsRoot: assets,
    matrix: HostMatrix.builtIn(),
    ledgerFile: LedgerFile(p.join(tmp.path, 'state', 'ledger.json')),
  );

  Future<(int, String)> run(List<String> args) async {
    final out = StringBuffer();
    final sink = _BufferSink(out);
    final ws = workspace();
    final code = await runSkillwire(
      args,
      stdout: sink,
      stderr: sink,
      workspace: ws,
      catalogue: Catalogue.read(
        assets,
        validator: SkillValidator(reservedNames: ws.matrix.reservedNames),
      ),
    );
    return (code, out.toString());
  }

  String claudeSkills() => p.join(home, '.claude', 'skills');

  group('R12.2 - nothing is implicit', () {
    test('an omitted --host is an error, not every host', () async {
      final (code, out) = await run(['skill', 'deploy', '--scope', 'global', '--all', '--plan']);
      expect(code, isNot(0));
      expect(out, contains('--host is required'));
    });

    test('an omitted --scope is an error, not global', () async {
      final (code, out) = await run(['skill', 'deploy', '--host', 'claude', '--all', '--plan']);
      expect(code, isNot(0));
      expect(out, contains('--scope is required'));
    });

    test('an omitted artifact set is an error, not everything', () async {
      final (code, out) = await run(
        ['skill', 'deploy', '--host', 'claude', '--scope', 'global', '--plan'],
      );
      expect(code, isNot(0));
      expect(out, contains('--skill, --module or --all'));
    });

    test('two artifact selectors at once are ambiguous, not merged', () async {
      final (code, out) = await run([
        'skill', 'deploy', '--host', 'claude', '--scope', 'global',
        '--all', '--skill', 'legion', '--plan',
      ]);
      expect(code, isNot(0));
      expect(out, contains('exactly one'));
    });

    test('an unknown host is named back, with the known ones', () async {
      final (code, out) = await run([
        'skill', 'deploy', '--host', 'borg', '--scope', 'global', '--all', '--plan',
      ]);
      expect(code, isNot(0));
      expect(out, contains('borg'));
      expect(out, contains('claude'));
    });
  });

  group('R12.4 - plan or apply, never a default', () {
    test('a Command with neither is refused and changes nothing', () async {
      final (code, _) = await run(
        ['skill', 'deploy', '--host', 'claude', '--scope', 'global', '--all'],
      );
      expect(code, isNot(0));
      expect(Directory(claudeSkills()).existsSync(), isFalse);
    });

    test('a Query rejects --plan', () async {
      final (code, out) = await run([
        'skill', 'list', '--host', 'claude', '--scope', 'global', '--all', '--plan',
      ]);
      expect(code, isNot(0));
      expect(out, contains('plan'));
    });
  });

  group('deploy', () {
    Future<(int, String)> deploy({
      String hosts = 'claude',
      bool force = false,
      String selector = '--all',
    }) => run([
      'skill', 'deploy', '--host', hosts, '--scope', 'global', selector,
      '--apply', '--autoapprove', if (force) '--force',
    ]);

    test('--plan writes nothing', () async {
      await run(['skill', 'deploy', '--host', 'claude', '--scope', 'global', '--all', '--plan']);
      expect(Directory(claudeSkills()).existsSync(), isFalse);
    });

    test('--apply creates the artifacts', () async {
      final (code, _) = await deploy();
      expect(code, 0);
      expect(
        Directory(claudeSkills()).listSync().map((e) => p.basename(e.path)).toSet(),
        {'legion', 'kritik'},
      );
      expect(File(p.join(claudeSkills(), 'legion', 'SKILL.md')).existsSync(), isTrue);
    });

    test('R10.5 - a second apply is a no-op', () async {
      await deploy();
      final before = File(p.join(claudeSkills(), 'legion', 'SKILL.md')).lastModifiedSync();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await deploy();
      expect(
        File(p.join(claudeSkills(), 'legion', 'SKILL.md')).lastModifiedSync(),
        before,
        reason: 'keep must not rewrite the file',
      );
    });

    test('the ledger records the acting consumer and the version', () async {
      await deploy();
      final ledger = workspace().ledgerFile.read();
      final row = ledger[const Unit(
        artifact: 'kritik',
        kind: Kind.skill,
        host: 'claude',
        scope: Scope.global,
      )]!;
      expect(row.owningConsumer, actingConsumer);
      expect(row.artifactVersion, '2.1.0');
      expect(row.resolvedDestinationPath, p.join(claudeSkills(), 'kritik'));
    });

    test('several hosts in one comma-separated --host', () async {
      // PRD 12.3 calls --host repeatable; cli_router keeps flags in a map, so a
      // second --host would silently overwrite the first. A comma-separated
      // list is the only spelling that cannot lose one without saying so.
      final (code, _) = await deploy(hosts: 'claude,opencode');
      expect(code, 0);
      expect(
        Directory(p.join(home, '.config', 'opencode', 'skills')).existsSync(),
        isTrue,
      );
    });
  });

  group('PRD 10.2 states, through the CLI', () {
    Future<void> deployOnce() => run([
      'skill', 'deploy', '--host', 'claude', '--scope', 'global', '--all',
      '--apply', '--autoapprove',
    ]);

    void dropLedgerRow(String artifact) {
      final f = workspace().ledgerFile;
      final ledger = f.read();
      ledger.remove(Unit(
        artifact: artifact,
        kind: Kind.skill,
        host: 'claude',
        scope: Scope.global,
      ));
      f.write(ledger);
    }

    test('state 3 - a changed asset plans replace', () async {
      await deployOnce();
      writeSkill('core', 'legion', body: '# Changed\n');
      final (_, out) = await run([
        'skill', 'deploy', '--host', 'claude', '--scope', 'global',
        '--skill', 'legion', '--plan',
      ]);
      expect(out, contains('replace'));
    });

    test('state 4 - an edited destination blocks, and --force does not lift it',
        () async {
      await deployOnce();
      File(p.join(claudeSkills(), 'legion', 'SKILL.md'))
          .writeAsStringSync('hand-edited');

      final (_, planned) = await run([
        'skill', 'deploy', '--host', 'claude', '--scope', 'global',
        '--skill', 'legion', '--plan',
      ]);
      expect(planned, contains('block'));
      expect(planned, contains('modified'));

      final (code, _) = await run([
        'skill', 'deploy', '--host', 'claude', '--scope', 'global',
        '--skill', 'legion', '--apply', '--force', '--autoapprove',
      ]);
      expect(code, isNot(0));
      expect(
        File(p.join(claudeSkills(), 'legion', 'SKILL.md')).readAsStringSync(),
        'hand-edited',
        reason: 'rule 1: the edit must survive',
      );
    });

    test('state 6 - unledgered blocks without --force', () async {
      await deployOnce();
      dropLedgerRow('legion');
      final (code, out) = await run([
        'skill', 'deploy', '--host', 'claude', '--scope', 'global',
        '--skill', 'legion', '--apply', '--autoapprove',
      ]);
      expect(code, isNot(0));
      expect(out, contains('refuses to apply'));
    });

    test('R10.6 - --force adopts it, writing nothing to the destination',
        () async {
      await deployOnce();
      final before =
          File(p.join(claudeSkills(), 'legion', 'SKILL.md')).lastModifiedSync();
      dropLedgerRow('legion');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final (code, out) = await run([
        'skill', 'deploy', '--host', 'claude', '--scope', 'global',
        '--skill', 'legion', '--apply', '--force', '--autoapprove',
      ]);
      expect(code, 0);
      expect(out, contains('adopt'));
      expect(
        File(p.join(claudeSkills(), 'legion', 'SKILL.md')).lastModifiedSync(),
        before,
        reason: 'adoption is a ledger-only operation (R10.6)',
      );

      final row = workspace().ledgerFile.read()[const Unit(
        artifact: 'legion',
        kind: Kind.skill,
        host: 'claude',
        scope: Scope.global,
      )]!;
      expect(row.wasAdopted, isTrue);
    });

    test('state 5 - another consumer owns it, and --force will not touch it',
        () async {
      await deployOnce();
      final f = workspace().ledgerFile;
      final ledger = f.read();
      const unit = Unit(
        artifact: 'legion',
        kind: Kind.skill,
        host: 'claude',
        scope: Scope.global,
      );
      final row = ledger[unit]!;
      ledger.put(
        unit,
        LedgerRow(
          sourceType: row.sourceType,
          sourceReference: row.sourceReference,
          resolvedDestinationPath: row.resolvedDestinationPath,
          contentHash: row.contentHash,
          owningConsumer: 'macss',
          artifactVersion: row.artifactVersion,
          created: row.created,
          updated: row.updated,
        ),
      );
      f.write(ledger);

      final (code, out) = await run([
        'skill', 'deploy', '--host', 'claude', '--scope', 'global',
        '--skill', 'legion', '--apply', '--force', '--autoapprove',
      ]);
      expect(code, isNot(0));
      expect(out, contains('macss'));
      expect(Directory(p.join(claudeSkills(), 'legion')).existsSync(), isTrue);
    });

    test('R10.3 - remove never acts on another consumer\'s artifact', () async {
      await deployOnce();
      final f = workspace().ledgerFile;
      final ledger = f.read();
      const unit = Unit(
        artifact: 'legion',
        kind: Kind.skill,
        host: 'claude',
        scope: Scope.global,
      );
      final row = ledger[unit]!;
      ledger.put(unit, LedgerRow(
        sourceType: row.sourceType,
        sourceReference: row.sourceReference,
        resolvedDestinationPath: row.resolvedDestinationPath,
        contentHash: row.contentHash,
        owningConsumer: 'macss',
        artifactVersion: row.artifactVersion,
        created: row.created,
        updated: row.updated,
      ));
      f.write(ledger);

      await run([
        'skill', 'remove', '--host', 'claude', '--scope', 'global',
        '--skill', 'legion', '--apply', '--force', '--autoapprove',
      ]);
      expect(Directory(p.join(claudeSkills(), 'legion')).existsSync(), isTrue);
    });
  });

  group('remove', () {
    test('takes back what this consumer deployed and drops the row', () async {
      await run(['skill', 'deploy', '--host', 'claude', '--scope', 'global',
        '--all', '--apply', '--autoapprove']);
      final (code, _) = await run(['skill', 'remove', '--host', 'claude',
        '--scope', 'global', '--all', '--apply', '--autoapprove']);
      expect(code, 0);
      expect(Directory(p.join(claudeSkills(), 'legion')).existsSync(), isFalse);
      expect(workspace().ledgerFile.read().rows, isEmpty);
    });

    test('removing what was never there is absent, not an error', () async {
      final (code, out) = await run(['skill', 'remove', '--host', 'claude',
        '--scope', 'global', '--all', '--plan']);
      expect(code, 0);
      expect(out, contains('absent'));
    });
  });

  group('list', () {
    test('renders the eight columns PRD 12.2 names', () async {
      final (_, out) = await run(
        ['skill', 'list', '--host', 'claude', '--scope', 'global', '--all'],
      );
      for (final h in ['name', 'version', 'module', 'kind', 'host', 'scope',
        'status', 'also visible from']) {
        expect(out, contains(h));
      }
    });

    test('the eighth column names a detected host that was not targeted', () async {
      final (_, out) = await run(
        ['skill', 'list', '--host', 'claude', '--scope', 'global', '--all'],
      );
      // OpenCode reads ~/.claude/skills and is installed on this fabricated
      // machine, so it belongs in the column (R7.2, R7.4).
      expect(out, contains('opencode'));
    });

    test('status is live, not an inventory', () async {
      final (_, before) = await run(
        ['skill', 'list', '--host', 'claude', '--scope', 'global', '--all'],
      );
      expect(before, contains('create'));

      await run(['skill', 'deploy', '--host', 'claude', '--scope', 'global',
        '--all', '--apply', '--autoapprove']);

      final (_, after) = await run(
        ['skill', 'list', '--host', 'claude', '--scope', 'global', '--all'],
      );
      expect(after, contains('keep'));
    });
  });

  group('validate', () {
    test('a conforming release is clean', () async {
      final (code, out) = await run(['skill', 'validate']);
      expect(code, 0);
      expect(out, contains('legion: ok'));
    });

    test('a broken skill fails with its findings, not a bare code', () async {
      File(p.join(assets, 'skills', 'modules', 'core', 'legion', 'SKILL.md'))
          .writeAsStringSync('---\nname: wrong-name\ndescription: d\n---\n');
      final (code, out) = await run(['skill', 'validate']);
      expect(code, isNot(0));
      expect(out, contains('must match the parent directory name'));
      expect(out, contains('metadata.version'));
    });

    test('R13.2 - a name in two modules is reported', () async {
      writeSkill('other', 'legion');
      final (code, out) = await run(['skill', 'validate']);
      expect(code, isNot(0));
      expect(out, contains('more than one module'));
    });

    test('a duplicate name stops deploy before it writes', () async {
      writeSkill('other', 'legion');
      final (code, _) = await run(['skill', 'deploy', '--host', 'claude',
        '--scope', 'global', '--all', '--apply', '--autoapprove']);
      expect(code, isNot(0));
      expect(Directory(claudeSkills()).existsSync(), isFalse);
    });
  });

  group('doctor', () {
    test('reports the machine before anything is deployed', () async {
      final (code, out) = await run(['skill', 'doctor']);
      expect(code, 0);
      expect(out, contains('claude'));
      expect(out, contains('not written yet'));
    });

    test('counts what this consumer owns', () async {
      await run(['skill', 'deploy', '--host', 'claude', '--scope', 'global',
        '--all', '--apply', '--autoapprove']);
      final (_, out) = await run(['skill', 'doctor']);
      expect(out, contains('intact:  2'));
    });

    test('drift is a finding, and names the artifact', () async {
      await run(['skill', 'deploy', '--host', 'claude', '--scope', 'global',
        '--all', '--apply', '--autoapprove']);
      File(p.join(claudeSkills(), 'legion', 'SKILL.md')).writeAsStringSync('edited');

      final (code, out) = await run(['skill', 'doctor']);
      expect(code, isNot(0));
      expect(out, contains('Modified since deployment:          1'));
      expect(out, contains('legion'));
    });
  });

  group('R13.9 - compatibility is reported, never enforced', () {
    test('a skill written for another product still deploys, with a notice',
        () async {
      writeSkill('core', 'legion', compatibility: 'Designed for Codex');
      final (code, out) = await run([
        'skill', 'deploy', '--host', 'claude', '--scope', 'global',
        '--skill', 'legion', '--plan',
      ]);
      expect(code, 0);
      expect(out, contains('create'), reason: 'prose must not become a rule');
      expect(out, contains('Designed for Codex'));
    });

    test('and carries no notice when it names the target host', () async {
      writeSkill('core', 'legion', compatibility: 'Designed for Claude Code');
      final (_, out) = await run([
        'skill', 'deploy', '--host', 'claude', '--scope', 'global',
        '--skill', 'legion', '--plan',
      ]);
      expect(out, isNot(contains('declares compatibility')));
    });
  });

  group('version', () {
    test('is reported, and matches the pubspec', () async {
      final (code, out) = await run(['version']);
      expect(code, 0);
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final declared = RegExp(r'^version:\s*(\S+)', multiLine: true)
          .firstMatch(pubspec)!
          .group(1)!;
      expect(out, contains(declared));
    });
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
