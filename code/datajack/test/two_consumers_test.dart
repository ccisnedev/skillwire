import 'dart:convert';
import 'dart:io';

import 'package:datajack/datajack.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;
import 'package:skillwire/skillwire.dart';
import 'package:test/test.dart';

/// The reason this package exists, tested where it can be tested.
///
/// One module, mounted by two different consumers against one shared ledger.
/// Everything the architecture claims about multiple CLIs sharing a machine
/// reduces to this: does the second one see what the first one did, and does it
/// leave it alone.
void main() {
  late Directory tmp;
  late String home;

  /// The one shared ledger every consumer on this machine writes to (R11.5).
  late String sharedLedger;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('datajack_');
    home = p.join(tmp.path, 'home');
    sharedLedger = p.join(tmp.path, 'state', 'ledger.json');
    Directory(p.join(home, '.claude')).createSync(recursive: true);
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  /// A consumer's own assets: `assets/skills/modules/<module>/<skill>/`.
  String assetsFor(String consumer, List<String> skills, {String body = 'x'}) {
    final root = p.join(tmp.path, consumer, 'assets');
    for (final name in skills) {
      final f = File(
        p.join(root, 'skills', 'modules', 'core', name, 'SKILL.md'),
      );
      f.parent.createSync(recursive: true);
      f.writeAsStringSync(
        '---\n'
        'name: $name\n'
        'description: Shipped by $consumer for this test.\n'
        'license: MIT\n'
        'metadata:\n'
        '  version: "1.0.0"\n'
        '  skillwire-origin: $consumer\n'
        '---\n\n$body\n',
      );
    }
    return root;
  }


  /// Mount the module as [consumer] and run one invocation.
  Future<(int, String)> run(
    String consumer,
    String assetsRoot,
    List<String> args,
  ) async {
    final buffer = StringBuffer();
    final sink = _BufferSink(buffer);

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

    final cli = ModularCli();
    cli.module(
      'skill',
      (m) => buildSkillModule(
        m,
        consumer: consumer,
        workspace: workspace,
        catalogue: catalogue,
      ),
    );

    final code = await cli.run(args, stdout: sink, stderr: sink);
    return (code, buffer.toString());
  }

  Future<(int, String)> deploy(String consumer, String assets, {bool force = false}) =>
      run(consumer, assets, [
        'skill', 'deploy', '--host', 'claude', '--scope', 'global', '--all',
        '--apply', '--autoapprove', if (force) '--force',
      ]);

  group('one module, two consumers, one ledger', () {
    test('each records itself as the owner', () async {
      await deploy('macss', assetsFor('macss', ['macss-plan']));
      await deploy('inquiry', assetsFor('inquiry', ['iq-review']));

      final ledger = LedgerFile(sharedLedger).read();
      final owners = {
        for (final e in ledger.rows.entries)
          e.key.artifact: e.value.owningConsumer,
      };
      expect(owners, {'macss-plan': 'macss', 'iq-review': 'inquiry'});
    });

    test('R11.5 - one file holds both, which is what makes state 5 answerable',
        () async {
      await deploy('macss', assetsFor('macss', ['macss-plan']));
      await deploy('inquiry', assetsFor('inquiry', ['iq-review']));

      final ledger = LedgerFile(sharedLedger).read();
      expect(ledger.ownedBy('macss'), hasLength(1));
      expect(ledger.ownedBy('inquiry'), hasLength(1));
    });

    test('the second consumer blocks on the first one\'s artifact', () async {
      // Both ship a skill of the same name — the collision the ledger exists
      // to make visible. Whoever gets there first owns it.
      final macss = assetsFor('macss', ['shared-name'], body: 'macss body');
      final inquiry = assetsFor('inquiry', ['shared-name'], body: 'inquiry body');

      final (firstCode, _) = await deploy('macss', macss);
      expect(firstCode, 0);

      final (secondCode, out) = await deploy('inquiry', inquiry);
      expect(secondCode, isNot(0));
      expect(out, contains('deployed by macss'));
    });

    test('and --force does not lift it (rule 1)', () async {
      final macss = assetsFor('macss', ['shared-name'], body: 'macss body');
      final inquiry = assetsFor('inquiry', ['shared-name'], body: 'inquiry body');

      await deploy('macss', macss);
      final (code, _) = await deploy('inquiry', inquiry, force: true);

      expect(code, isNot(0));
      expect(
        File(p.join(home, '.claude', 'skills', 'shared-name', 'SKILL.md'))
            .readAsStringSync(),
        contains('macss body'),
        reason: 'the first consumer\'s bytes must survive the second\'s --force',
      );
    });

    test('R10.3 - and neither can remove it', () async {
      final macss = assetsFor('macss', ['shared-name']);
      final inquiry = assetsFor('inquiry', ['shared-name']);

      await deploy('macss', macss);
      await run('inquiry', inquiry, [
        'skill', 'remove', '--host', 'claude', '--scope', 'global', '--all',
        '--apply', '--force', '--autoapprove',
      ]);

      expect(
        Directory(p.join(home, '.claude', 'skills', 'shared-name')).existsSync(),
        isTrue,
      );
    });

    test('each removes only its own, leaving the other standing', () async {
      final macss = assetsFor('macss', ['macss-plan']);
      final inquiry = assetsFor('inquiry', ['iq-review']);
      await deploy('macss', macss);
      await deploy('inquiry', inquiry);

      await run('macss', macss, [
        'skill', 'remove', '--host', 'claude', '--scope', 'global', '--all',
        '--apply', '--autoapprove',
      ]);

      final skills = p.join(home, '.claude', 'skills');
      expect(Directory(p.join(skills, 'macss-plan')).existsSync(), isFalse);
      expect(Directory(p.join(skills, 'iq-review')).existsSync(), isTrue);
      expect(LedgerFile(sharedLedger).read().ownedBy('inquiry'), hasLength(1));
    });
  });

  group('doctor speaks for whoever mounted it', () {
    test('it names its own consumer, and counts the other as foreign', () async {
      await deploy('macss', assetsFor('macss', ['macss-plan']));
      await deploy('inquiry', assetsFor('inquiry', ['iq-review']));

      final (_, out) = await run('macss', assetsFor('macss', ['macss-plan']), [
        'skill', 'doctor',
      ]);
      expect(out, contains('Deployed by macss, intact: 1'));
      expect(out, contains('Deployed by another consumer: 1'));
    });

    test('the same machine reads differently to the other consumer', () async {
      await deploy('macss', assetsFor('macss', ['macss-plan']));
      await deploy('inquiry', assetsFor('inquiry', ['iq-review']));

      final (_, out) = await run(
        'inquiry',
        assetsFor('inquiry', ['iq-review']),
        ['skill', 'doctor'],
      );
      expect(out, contains('Deployed by inquiry, intact: 1'));
    });
  });

  group('the module is the same in every consumer (R12.1)', () {
    test('it mounts under any name a consumer gives it', () async {
      for (final consumer in ['skillwire_cli', 'macss', 'inquiry']) {
        final (code, _) = await run(
          consumer,
          assetsFor(consumer, ['$consumer-skill'.replaceAll('_', '-')]),
          ['skill', 'validate'],
        );
        expect(code, 0, reason: consumer);
      }
    });

    test('all five routes are registered', () async {
      final assets = assetsFor('macss', ['macss-plan']);
      final (_, out) = await run('macss', assets, ['skill', '--help']);
      for (final route in ['list', 'deploy', 'remove', 'doctor', 'validate']) {
        expect(out, contains(route), reason: route);
      }
    });
  });
}

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
