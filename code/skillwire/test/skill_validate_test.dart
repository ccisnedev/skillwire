import 'dart:convert';
import 'dart:typed_data';

import 'package:skillwire/skillwire.dart';
import 'package:test/test.dart';

/// PRD 13.1, field by field. One assertion per constraint, because a validator
/// tested in aggregate passes for the wrong reason.
void main() {
  final validator = SkillValidator(
    reservedNames: HostMatrix.builtIn().reservedNames,
  );

  Map<String, Uint8List> md(String content) => {
    'SKILL.md': Uint8List.fromList(utf8.encode(content)),
  };

  String doc({
    String name = 'legion',
    String description = 'Convoke a council of experts. Use when a problem spans domains.',
    String? license = 'MIT',
    String? compatibility,
    String metadata = '  version: "1.0.0"\n  skillwire-origin: skillwire_cli\n',
  }) =>
      '---\n'
      'name: $name\n'
      'description: $description\n'
      '${license == null ? '' : 'license: $license\n'}'
      '${compatibility == null ? '' : 'compatibility: $compatibility\n'}'
      '${metadata.isEmpty ? '' : 'metadata:\n$metadata'}'
      '---\n\n# Body\n';

  ValidationResult check(String content, {String dir = 'legion', Map<String, Uint8List>? extra}) =>
      validator.validate(
        directoryName: dir,
        tree: {...md(content), ...?extra},
      );

  List<String> rules(ValidationResult r) => r.findings.map((f) => f.rule).toList();

  group('a conforming skill', () {
    test('validates clean', () {
      final r = check(doc());
      expect(r.isValid, isTrue, reason: r.findings.join('; '));
    });

    test('its frontmatter is readable afterwards', () {
      final f = check(doc()).frontmatter!;
      expect(f.name, 'legion');
      expect(f.version, '1.0.0');
      expect(f.skillwireOrigin, 'skillwire_cli');
      expect(f.license, 'MIT');
    });
  });

  group('13.1 name', () {
    test('accepts a name equal to the directory name', () {
      expect(check(doc(name: 'legion'), dir: 'legion').isValid, isTrue);
    });

    test('rejects a name that differs from the directory name', () {
      // Normative, and the citation R7.5 rests on: a suffix creates a second
      // artifact rather than disambiguating one.
      expect(rules(check(doc(name: 'legion'), dir: 'legion-opencode')),
          contains('13.1 name'));
    });

    test('rejects uppercase', () {
      expect(rules(check(doc(name: 'Legion'), dir: 'Legion')), contains('13.1 name'));
    });

    test('rejects a leading hyphen', () {
      expect(rules(check(doc(name: '-legion'), dir: '-legion')), contains('13.1 name'));
    });

    test('rejects a trailing hyphen', () {
      expect(rules(check(doc(name: 'legion-'), dir: 'legion-')), contains('13.1 name'));
    });

    test('rejects consecutive hyphens', () {
      expect(rules(check(doc(name: 'le--gion'), dir: 'le--gion')),
          contains('13.1 name'));
    });

    test('accepts a single interior hyphen', () {
      expect(check(doc(name: 'macss-plan'), dir: 'macss-plan').isValid, isTrue);
    });

    test('accepts 64 characters', () {
      final n = 'a' * 64;
      expect(check(doc(name: n), dir: n).isValid, isTrue);
    });

    test('rejects 65', () {
      final n = 'a' * 65;
      expect(rules(check(doc(name: n), dir: n)), contains('13.1 name'));
    });

    test('rejects an empty name', () {
      expect(rules(check(doc(name: '""'), dir: '')), contains('13.1 name'));
    });
  });

  group('13.1 description', () {
    test('rejects empty', () {
      expect(rules(check(doc(description: '""'))), contains('13.1 description'));
    });

    test('accepts 1024 characters', () {
      expect(check(doc(description: 'd' * 1024)).isValid, isTrue);
    });

    test('rejects 1025', () {
      expect(rules(check(doc(description: 'd' * 1025))),
          contains('13.1 description'));
    });
  });

  group('13.1 compatibility - validated, never parsed (R13.9)', () {
    test('accepts its absence', () {
      expect(check(doc()).isValid, isTrue);
    });

    test('accepts 500 characters', () {
      expect(check(doc(compatibility: 'c' * 500)).isValid, isTrue);
    });

    test('rejects 501', () {
      expect(rules(check(doc(compatibility: 'c' * 501))),
          contains('13.1 compatibility'));
    });

    test('a product name in it is not a rule, only prose', () {
      // R13.9: the specification defines it as prose. Reading structure into
      // prose invents a grammar nobody wrote. The reader decides.
      final r = check(doc(compatibility: 'Designed for Claude Code'));
      expect(r.isValid, isTrue);
      expect(r.frontmatter!.compatibility, 'Designed for Claude Code');
    });
  });

  group('13.1 metadata is a map of string to string', () {
    test('rejects an unquoted number', () {
      // `version: 1.0` is the trap: YAML reads it as a double, and the
      // specification says string values.
      final r = check(doc(metadata: '  version: 1.0\n  skillwire-origin: x\n'));
      expect(rules(r), contains('13.1'));
      expect(r.findings.map((f) => f.detail).join(), contains('double'));
    });

    test('rejects a nested map', () {
      final r = check(doc(metadata: '  version:\n    major: 1\n  skillwire-origin: x\n'));
      expect(r.isValid, isFalse);
    });

    test('rejects metadata that is not a mapping at all', () {
      final r = check('---\nname: legion\ndescription: d\nmetadata: nope\n---\n');
      expect(r.findings.map((f) => f.detail).join(), contains('mapping'));
    });

    test('ignores unknown keys', () {
      // The specification lets clients store properties it does not define, so
      // another tool's key is that tool's business, not an error.
      final r = check(doc(
        metadata: '  version: "1.0.0"\n  skillwire-origin: x\n  someone-else: y\n',
      ));
      expect(r.isValid, isTrue, reason: r.findings.join('; '));
    });
  });

  group('R13.6 - the two keys', () {
    test('requires metadata.version', () {
      expect(rules(check(doc(metadata: '  skillwire-origin: x\n'))), contains('R13.6'));
    });

    test('requires it to be SemVer', () {
      for (final bad in ['1.0', 'v1.0.0', 'latest', '1']) {
        expect(
          rules(check(doc(metadata: '  version: "$bad"\n  skillwire-origin: x\n'))),
          contains('R13.6'),
          reason: bad,
        );
      }
    });

    test('accepts a prerelease', () {
      expect(
        check(doc(metadata: '  version: "1.0.0-rc.1"\n  skillwire-origin: x\n')).isValid,
        isTrue,
      );
    });

    test('requires metadata.skillwire-origin', () {
      expect(rules(check(doc(metadata: '  version: "1.0.0"\n'))), contains('R13.6'));
    });
  });

  group('R13.7 - license is the top-level field', () {
    test('rejects license inside metadata', () {
      final r = check(doc(
        metadata: '  version: "1.0.0"\n  skillwire-origin: x\n  license: MIT\n',
      ));
      expect(rules(r), contains('R13.7'));
    });

    test('accepts license at the top level', () {
      expect(check(doc(license: 'Apache-2.0')).isValid, isTrue);
    });

    test('accepts its absence entirely', () {
      expect(check(doc(license: null)).isValid, isTrue);
    });
  });

  group('structure', () {
    test('rejects a directory with no SKILL.md', () {
      final r = validator.validate(directoryName: 'legion', tree: const {});
      expect(rules(r), contains('13.1'));
    });

    test('rejects a directory containing skill.yaml (R13.3)', () {
      final r = check(doc(), extra: {'skill.yaml': Uint8List(0)});
      expect(rules(r), contains('R13.3'));
    });

    test('rejects SKILL.md with no frontmatter', () {
      expect(check('# Just a heading\n').isValid, isFalse);
    });

    test('accepts CRLF frontmatter', () {
      expect(check(doc().replaceAll('\n', '\r\n')).isValid, isTrue);
    });

    test('accepts a CHANGELOG.md beside SKILL.md (R13.3 permits it)', () {
      expect(
        check(doc(), extra: {'CHANGELOG.md': Uint8List.fromList(utf8.encode('# 1.0.0'))})
            .isValid,
        isTrue,
      );
    });

    test('reports every failure, not the first', () {
      final r = check(doc(name: 'Wrong', description: '""', metadata: ''), dir: 'legion');
      expect(r.findings.length, greaterThanOrEqualTo(4));
    });
  });

  group('R6.11 - reserved names', () {
    test('synced is rejected', () {
      expect(rules(check(doc(name: 'synced'), dir: 'synced')), contains('R6.11'));
    });

    test('in any capitalisation', () {
      expect(rules(check(doc(name: 'synced'), dir: 'Synced')), contains('R6.11'));
    });
  });
}
