import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:skillwire/skillwire.dart';
import 'package:test/test.dart';

/// The two edges: reading a tree off a disk, and writing a plan's effects to
/// one. Everything between them is pure and tested elsewhere.
void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('skillwire_io_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  String at(String rel) => p.join(tmp.path, rel);

  void writeFile(String rel, String content) {
    final f = File(at(rel));
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(content);
  }

  const unit = Unit(
    artifact: 'legion',
    kind: Kind.skill,
    host: 'claude',
    scope: Scope.global,
  );

  group('readTree', () {
    test('reads nested files with forward-slash relative paths', () {
      writeFile('src/SKILL.md', 'body');
      writeFile('src/references/R.md', 'more');
      final tree = readTree(at('src'));
      expect(tree.keys.toSet(), {'SKILL.md', 'references/R.md'});
    });

    test('a missing directory is empty, not an error', () {
      expect(readTree(at('nope')), isEmpty);
    });

    test('an empty directory contributes nothing', () {
      Directory(at('src/empty')).createSync(recursive: true);
      writeFile('src/SKILL.md', 'x');
      expect(readTree(at('src')).keys, ['SKILL.md']);
    });

    test('a round trip through the sink preserves the hash', () async {
      writeFile('src/SKILL.md', 'body\n');
      writeFile('src/references/R.md', 'more\n');
      final source = readTree(at('src'));

      final sink = FilesystemSink(
        ledgerFile: LedgerFile(at('ledger.json')),
        actingConsumer: 'skillwire_cli',
        sourceType: SourceType.local,
        sourceReference: at('src'),
        artifactVersions: const {'legion': '1.0.0'},
      );
      await sink.writeTree(at('dest'), source);

      expect(contentHash(readTree(at('dest'))), contentHash(source));
    });
  });

  group('FilesystemSink writes whole or not at all', () {
    late FilesystemSink sink;
    late LedgerFile ledgerFile;

    setUp(() {
      ledgerFile = LedgerFile(at('ledger.json'));
      sink = FilesystemSink(
        ledgerFile: ledgerFile,
        actingConsumer: 'skillwire_cli',
        sourceType: SourceType.local,
        sourceReference: 'assets',
        artifactVersions: const {'legion': '1.0.0'},
      );
    });

    Map<String, Uint8List> tree(String body) => {
      'SKILL.md': Uint8List.fromList(utf8.encode(body)),
    };

    test('replacing removes files the new tree does not have', () async {
      await sink.writeTree(at('dest'), {
        ...tree('one'),
        'gone.md': Uint8List.fromList(utf8.encode('stale')),
      });
      await sink.writeTree(at('dest'), tree('two'));
      expect(readTree(at('dest')).keys, ['SKILL.md']);
    });

    test('no staging directory survives a write', () {
      expect(Directory(tmp.path).listSync().map((e) => p.basename(e.path)),
          isNot(contains(contains('skillwire-staging'))));
    });

    test('deleteTree on nothing is not an error', () async {
      await sink.deleteTree(at('never-existed'));
    });

    test('record writes a full R11.3 row', () async {
      await sink.writeTree(at('dest'), tree('one'));
      await sink.record(unit, at('dest'), contentHash(tree('one')));

      final row = ledgerFile.read()[unit]!;
      expect(row.owningConsumer, 'skillwire_cli');
      expect(row.artifactVersion, '1.0.0');
      expect(row.sourceType, SourceType.local);
      expect(row.sourceReference, 'assets');
      expect(row.resolvedDestinationPath, at('dest'));
      expect(row.contentHash, contentHash(tree('one')));
    });

    test('R11.3 - created survives a second record, updated moves', () async {
      await sink.record(unit, at('dest'), 'hash-one');
      final first = ledgerFile.read()[unit]!;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await sink.record(unit, at('dest'), 'hash-two');
      final second = ledgerFile.read()[unit]!;

      expect(second.created, first.created);
      expect(second.updated.isAfter(first.updated), isTrue);
    });

    test('forget drops the row', () async {
      await sink.record(unit, at('dest'), 'h');
      await sink.forget(unit);
      expect(ledgerFile.read()[unit], isNull);
    });
  });

  group('R11.5 - one ledger per machine, and where', () {
    test('SKILLWIRE_HOME wins when it is set', () {
      final f = LedgerFile.resolve(
        home: '/home/x',
        environment: {'SKILLWIRE_HOME': '/opt/sw'},
      );
      expect(p.normalize(f.path).replaceAll(r'\', '/'), '/opt/sw/ledger.json');
    });

    test('the default is ~/.skillwire/ledger.json', () {
      final f = LedgerFile.resolve(home: '/home/x', environment: const {});
      expect(p.normalize(f.path).replaceAll(r'\', '/'), '/home/x/.skillwire/ledger.json');
    });

    test('an empty variable counts as unset', () {
      final f = LedgerFile.resolve(
        home: '/home/x',
        environment: {'SKILLWIRE_HOME': ''},
      );
      expect(f.path, contains('.skillwire'));
    });

    test('two consumers share one file and each sees the other', () async {
      // This is what makes PRD 10.2 state 5 answerable. A ledger per consumer
      // could not answer "which other consumer owns this" at all for a consumer
      // it had never heard of.
      final ledgerFile = LedgerFile(at('shared.json'));
      const macssUnit = Unit(
        artifact: 'macss-plan',
        kind: Kind.skill,
        host: 'claude',
        scope: Scope.global,
      );

      for (final (consumer, u) in [('macss', macssUnit), ('inquiry', unit)]) {
        await FilesystemSink(
          ledgerFile: ledgerFile,
          actingConsumer: consumer,
          sourceType: SourceType.local,
          sourceReference: 'assets',
          artifactVersions: const {},
        ).record(u, at('d'), 'h');
      }

      final ledger = ledgerFile.read();
      expect(ledger.recordFor(macssUnit)!.owner, 'macss');
      expect(ledger.recordFor(unit)!.owner, 'inquiry');
      expect(ledger.ownedBy('macss').keys, [macssUnit]);
    });
  });

  group('R11.6 - durability', () {
    test('the encoded ledger carries a schema version', () {
      final f = LedgerFile(at('l.json'));
      f.write(Ledger());
      expect(jsonDecode(File(at('l.json')).readAsStringSync())['schemaVersion'], 1);
    });

    test('no .tmp file survives a write', () {
      LedgerFile(at('l.json')).write(Ledger());
      expect(File(at('l.json.tmp')).existsSync(), isFalse);
    });

    test('a missing ledger reads as empty - that is a first run', () {
      expect(LedgerFile(at('absent.json')).read().rows, isEmpty);
    });

    test('a corrupt ledger throws rather than reading as empty', () {
      // Treating it as empty would reclassify every deployed unit into state 6
      // and, under --force, invite adopting artifacts whose real ownership was
      // merely unreadable.
      writeFile('bad.json', '{not json');
      expect(
        () => LedgerFile(at('bad.json')).read(),
        throwsA(isA<LedgerUnreadable>()),
      );
    });

    test('a ledger from a newer schema throws rather than guessing', () {
      writeFile('future.json', '{"schemaVersion": 99, "units": {}}');
      expect(
        () => LedgerFile(at('future.json')).read(),
        throwsA(isA<LedgerUnreadable>()),
      );
    });

    test('a row round-trips through JSON', () {
      final ledger = Ledger()
        ..put(
          unit,
          LedgerRow(
            sourceType: SourceType.git,
            sourceReference: 'github.com/x@abc123',
            resolvedDestinationPath: '/d',
            contentHash: 'h',
            owningConsumer: 'skillwire_cli',
            artifactVersion: '1.2.3',
            created: DateTime.utc(2026, 8, 26, 7),
            updated: DateTime.utc(2026, 8, 26, 8),
          ),
        );
      final back = Ledger.decode(ledger.encode(), path: 'x')[unit]!;
      expect(back.sourceType, SourceType.git);
      expect(back.artifactVersion, '1.2.3');
      expect(back.created, DateTime.utc(2026, 8, 26, 7));
      expect(back.wasAdopted, isFalse);
    });

    test('an adopted row is distinguishable on inspection', () {
      // R10.6 adoption writes nothing to the destination, so created and
      // updated are the same instant.
      final t = DateTime.utc(2026, 8, 26);
      final row = LedgerRow(
        sourceType: SourceType.local,
        sourceReference: 'a',
        resolvedDestinationPath: '/d',
        contentHash: 'h',
        owningConsumer: 'c',
        artifactVersion: '1.0.0',
        created: t,
        updated: t,
      );
      expect(row.wasAdopted, isTrue);
    });

    test('the encoding is stable, so two ledgers diff legibly', () {
      final a = Ledger();
      final b = Ledger();
      for (final name in ['research', 'kritik']) {
        final u = Unit(
          artifact: name,
          kind: Kind.skill,
          host: 'claude',
          scope: Scope.global,
        );
        final row = LedgerRow(
          sourceType: SourceType.local,
          sourceReference: 'a',
          resolvedDestinationPath: '/d',
          contentHash: 'h',
          owningConsumer: 'c',
          artifactVersion: '1.0.0',
          created: DateTime.utc(2026),
          updated: DateTime.utc(2026),
        );
        a.put(u, row);
        b.put(u, row);
      }
      expect(a.encode(), b.encode());
    });
  });

  group('observe - the one read before', () {
    test('an absent destination observes as not present', () {
      final o = observe(
        destination: at('nothing'),
        unit: unit,
        ledger: Ledger(),
        hash: contentHash,
      );
      expect(o.isPresent, isFalse);
    });

    test('a present destination carries its hash', () {
      writeFile('dest/SKILL.md', 'body\n');
      final o = observe(
        destination: at('dest'),
        unit: unit,
        ledger: Ledger(),
        hash: contentHash,
      );
      expect(o.isPresent, isTrue);
      expect(o.contentHash, contentHash(readTree(at('dest'))));
      expect(o.ledger, isNull);
    });
  });
}
