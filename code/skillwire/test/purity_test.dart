import 'dart:io';

import 'package:test/test.dart';

/// The two prohibitions that cannot be enforced by a type, enforced by a scan.
///
/// This file is the one place in the suite that touches a disk, and it is named
/// so that it falls outside its own glob. Everything it checks is a rule a
/// reviewer would otherwise have to remember on every pull request.
void main() {
  List<File> dartFilesUnder(String dir) => Directory(dir)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  group('R10.4 - reconciliation never touches the filesystem', () {
    test('no file under lib/src/reconcile imports dart:io', () {
      // I/O belongs at the edges: one read before, one write after. The layer
      // in between is where a bug destroys a user's work, so it is a pure
      // function of two values and stays that way.
      final offenders = [
        for (final f in dartFilesUnder('lib/src/reconcile'))
          if (f.readAsStringSync().contains("import 'dart:io'")) f.path,
      ];
      expect(offenders, isEmpty,
          reason: 'reconciliation must decide with no I/O (R10.4)');
    });

    test('no reconciliation test imports dart:io either', () {
      // A pure layer tested through a disk is a pure layer whose purity nobody
      // is checking.
      final offenders = [
        for (final f in dartFilesUnder('test'))
          if (!f.path.endsWith('purity_test.dart') &&
              !f.path.endsWith('sink_test.dart') &&
              !f.path.endsWith('io_test.dart') &&
              f.readAsStringSync().contains("import 'dart:io'"))
            f.path,
      ];
      expect(offenders, isEmpty);
    });
  });

  group('R12.9 - the package produces steps and never runs them', () {
    test('nothing under lib references PreviewExecutor', () {
      // Depending on preview_executor directly (R12.8) puts the executor within
      // reach. modular_cli_sdk withholds it from command authors on stated
      // grounds: a command that could reach it could run steps with no plan
      // rendered, no approval taken, and no check that what happened is what
      // was announced. The package inherits the prohibition. This is
      // non-negotiable rule 3, one layer below the flag.
      final offenders = [
        for (final f in dartFilesUnder('lib'))
          if (f.readAsStringSync().contains('PreviewExecutor')) f.path,
      ];
      expect(offenders, isEmpty,
          reason: 'the package must not execute its own steps (R12.9)');
    });
  });

  group('R12.8 - the package depends on preview_executor, not the SDK', () {
    test('nothing under lib imports modular_cli_sdk', () {
      final offenders = [
        for (final f in dartFilesUnder('lib'))
          if (f.readAsStringSync().contains('package:modular_cli_sdk')) f.path,
      ];
      expect(offenders, isEmpty);
    });

    test('the pubspec declares preview_executor and not modular_cli_sdk', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('preview_executor:'));
      expect(pubspec, isNot(contains('modular_cli_sdk:')));
    });
  });
}
