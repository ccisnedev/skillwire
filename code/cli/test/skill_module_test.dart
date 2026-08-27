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
      expect(row.owningConsumer, consumerName);
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

  group('doctor - the machine', () {
    test('reports hosts and the ledger before anything is deployed', () async {
      final (code, out) = await run(['skill', 'doctor']);
      expect(code, 0);
      expect(out, contains('Hosts detected'));
      expect(out, contains('claude'));
      expect(out, contains('not written yet'));
      expect(out, contains('Nothing is recorded yet'));
    });

    test('names the hosts it did NOT find (R7.4 works both ways)', () async {
      final (_, out) = await run(['skill', 'doctor']);
      expect(out, contains('codex'));
      expect(out, contains('Hosts not found'));
    });

    test('reports where each host path came from (R14.2)', () async {
      final (_, out) = await run(['skill', 'doctor']);
      expect(out, contains('Where the host paths came from'));
      expect(out, contains('2026-08-26'));
      expect(out, contains('unverified again'));
    });
  });

  group('doctor - what the ledger claims', () {
    Future<void> deployAll() => run([
      'skill', 'deploy', '--host', 'claude', '--scope', 'global', '--all',
      '--apply', '--autoapprove',
    ]);

    test('counts what this consumer owns and leaves it healthy', () async {
      await deployAll();
      final (code, out) = await run(['skill', 'doctor']);
      expect(code, 0);
      expect(out, contains('intact: 2'));
    });

    test('drift is named, counted, and makes the run unhealthy', () async {
      await deployAll();
      File(p.join(claudeSkills(), 'legion', 'SKILL.md')).writeAsStringSync('edited');

      final (code, out) = await run(['skill', 'doctor']);
      expect(code, isNot(0));
      expect(out, contains('Modified since deployment: 1'));
      expect(out, contains('legion'));
    });

    test('a deleted artifact is MISSING, not modified', () async {
      // The defect this whole change began with. An absent directory hashes as
      // an empty tree, so it used to report as "modified at the destination"
      // with a remedy that was the opposite of the right one.
      await deployAll();
      Directory(p.join(claudeSkills(), 'legion')).deleteSync(recursive: true);

      final (code, out) = await run(['skill', 'doctor']);
      expect(code, isNot(0));
      expect(out, contains('gone from the destination'));
      expect(out, isNot(contains('Modified since deployment')));
    });

    test('missing tells you to deploy; drift tells you deploy will block',
        () async {
      await deployAll();
      Directory(p.join(claudeSkills(), 'legion')).deleteSync(recursive: true);
      File(p.join(claudeSkills(), 'kritik', 'SKILL.md')).writeAsStringSync('edited');

      final (_, out) = await run(['skill', 'doctor']);
      expect(out, contains('an ordinary deploy will recreate it'));
      expect(out, contains('deploy will block rather than lose the edits'));
    });

    test('and the remedies are true - missing really does recreate', () async {
      await deployAll();
      Directory(p.join(claudeSkills(), 'legion')).deleteSync(recursive: true);

      final (_, planned) = await run([
        'skill', 'deploy', '--host', 'claude', '--scope', 'global',
        '--skill', 'legion', '--plan',
      ]);
      expect(planned, contains('create'),
          reason: 'doctor promised an ordinary deploy would recreate it');
      expect(planned, isNot(contains('block')));
    });

    test('intact rows are counted, not listed', () async {
      // A wall of correct lines buries the two that are not.
      await deployAll();
      final (_, out) = await run(['skill', 'doctor']);
      expect(out, contains('intact: 2'));
      expect(out, isNot(contains(p.join(claudeSkills(), 'kritik'))));
    });
  });

  group('doctor - what the ledger does not know', () {
    void plantForeign(String name, {String? origin}) {
      final f = File(p.join(claudeSkills(), name, 'SKILL.md'));
      f.parent.createSync(recursive: true);
      f.writeAsStringSync(
        '---\nname: $name\ndescription: Planted by another tool.\n'
        '${origin == null ? '' : 'metadata:\n  skillwire-origin: $origin\n'}'
        '---\n',
      );
    }

    test('a directory nobody recorded is reported, under its directory', () async {
      plantForeign('macss-plan');
      final (code, out) = await run(['skill', 'doctor']);
      expect(out, contains('What the ledger does not know'));
      expect(out, contains(claudeSkills()));
      expect(out, contains('macss-plan'));
      expect(out, contains('read by claude/global'));
      // An ordinary machine has other tools on it. Calling that unhealthy would
      // teach the user to ignore the word.
      expect(code, 0);
    });

    test('a declared origin is reported as appearance, never as ownership',
        () async {
      plantForeign('macss-plan', origin: 'macss');
      final (_, out) = await run(['skill', 'doctor']);
      expect(out, contains('appears to be from: macss'));
    });

    test('what this consumer deployed is not reported as unknown', () async {
      await run(['skill', 'deploy', '--host', 'claude', '--scope', 'global',
        '--all', '--apply', '--autoapprove']);
      final (_, out) = await run(['skill', 'doctor']);
      expect(out, contains('Nothing in reach of a detected host is unaccounted for'));
    });

    test('R6.11 - the reserved synced directory is not an unknown occupant',
        () async {
      // Claude Code fills it from claude.ai. It is a known occupant, not an
      // unaccounted one.
      final f = File(p.join(claudeSkills(), 'synced', 'SKILL.md'));
      f.parent.createSync(recursive: true);
      f.writeAsStringSync('---\nname: synced\ndescription: from claude.ai\n---\n');

      final (code, out) = await run(['skill', 'doctor']);
      expect(code, 0);
      expect(out, contains('Nothing in reach of a detected host is unaccounted for'));
      expect(out, isNot(contains('synced')));
    });

    test('occupants are grouped by directory, not listed one per line', () async {
      // Five names in two directories is six lines grouped and thirty listed,
      // and the grouped form is the one that shows the shape: the same five
      // things, twice over.
      for (final n in ['a-one', 'a-two', 'a-three']) {
        plantForeign(n);
      }
      final (_, out) = await run(['skill', 'doctor']);
      expect(out, contains(claudeSkills()));
      expect(out, contains('a-one, a-three, a-two'));
      // The directory is named once, not once per occupant.
      expect(claudeSkills().allMatches(out).length, 1);
    });

    test('a verdict line says why the exit code is what it is', () async {
      plantForeign('macss-plan');
      final (code, out) = await run(['skill', 'doctor']);
      expect(code, 0);
      expect(out, contains('Verdict'));
      expect(out, contains('nothing to act on'));
    });

    test('a directory with no SKILL.md is not an artifact at all', () async {
      Directory(p.join(claudeSkills(), 'notes')).createSync(recursive: true);
      final (_, out) = await run(['skill', 'doctor']);
      expect(out, isNot(contains('notes')));
    });

    test('doctor creates nothing while looking', () async {
      // A diagnostic that leaves a directory behind is not a diagnosis.
      final before = Directory(home).listSync(recursive: true).length;
      await run(['skill', 'doctor']);
      expect(Directory(home).listSync(recursive: true).length, before);
    });
  });

  group('doctor - one artifact, more than one directory', () {
    test('R6.5 - both OpenCode spellings holding one name is actionable',
        () async {
      // OpenCode resolves its own tree with {skill,skills}, so it sees two
      // things the user can invoke that both claim to be legion.
      for (final spelling in ['skill', 'skills']) {
        final f = File(p.join(
          home, '.config', 'opencode', spelling, 'legion', 'SKILL.md',
        ));
        f.parent.createSync(recursive: true);
        f.writeAsStringSync('---\nname: legion\ndescription: d\n---\n');
      }

      final (code, out) = await run(['skill', 'doctor']);
      expect(code, isNot(0));
      expect(out, contains('One artifact, more than one directory'));
      expect(out, contains('Needs attention'));
      expect(out, contains('Verdict'));
    });

    test('the deliberate two-host deployment is expected, not a fault', () async {
      // Deploying to claude and opencode at global scope necessarily puts
      // legion where OpenCode sees it twice: it reads ~/.claude/skills and
      // cannot be prevented (PRD 7.4). No arrangement avoids it.
      await run(['skill', 'deploy', '--host', 'claude,opencode', '--scope',
        'global', '--all', '--apply', '--autoapprove']);

      final (code, out) = await run(['skill', 'doctor']);
      expect(code, 0, reason: 'irreducible is not a fault');
      expect(out, contains('Irreducible'));
      // Counted and named on one line, not spelled out per artifact: nobody can
      // do anything about it, so detail would only bury what they can.
      expect(out, contains('kritik, legion'));
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
