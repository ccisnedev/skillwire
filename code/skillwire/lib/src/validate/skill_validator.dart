import 'dart:convert';
import 'dart:typed_data';

import 'package:yaml/yaml.dart';

/// One thing wrong with an artifact, and the rule it breaks.
class Finding {
  const Finding(this.rule, this.detail);

  /// The requirement or specification field this comes from, so a user can look
  /// it up rather than guess what the tool wanted.
  final String rule;

  final String detail;

  @override
  String toString() => '$rule: $detail';
}

/// What a skill declares about itself.
class SkillFrontmatter {
  const SkillFrontmatter({
    required this.name,
    required this.description,
    this.license,
    this.compatibility,
    this.metadata = const {},
    this.allowedTools,
  });

  final String? name;
  final String? description;
  final String? license;

  /// Prose. Never parsed (R13.9) — the specification defines it as free text,
  /// and reading structure into prose invents a grammar nobody wrote.
  final String? compatibility;

  final Map<String, String> metadata;
  final String? allowedTools;

  /// SemVer, from `metadata.version` (R13.6). Unprefixed because it is the key
  /// the specification's own example uses.
  String? get version => metadata['version'];

  /// The consumer that transports this skill, from `metadata.skillwire-origin`
  /// (R13.6). **Not ownership** (R13.8) — anyone can type it into a file. It
  /// lets a state 6 block say who *appears* to have deployed a directory
  /// instead of only that nobody recorded it.
  String? get skillwireOrigin => metadata['skillwire-origin'];
}

/// The result of validating one artifact directory.
class ValidationResult {
  const ValidationResult({
    required this.artifact,
    required this.findings,
    this.frontmatter,
  });

  final String artifact;

  /// Every fault, not the first. A user fixing one at a time across four runs
  /// is a worse experience than fixing four at once.
  final List<Finding> findings;

  /// Null when the file could not be parsed far enough to produce one.
  final SkillFrontmatter? frontmatter;

  bool get isValid => findings.isEmpty;
}

/// Conformance to the Agent Skills specification, as PRD 13.1 reproduces it.
///
/// Implemented here rather than delegated: the reference validator `skills-ref`
/// is Python and describes itself as for demonstration, and no machine-readable
/// schema is published. There is nothing to consume and nothing to shell out to.
///
/// Pure. It takes a map of relative path to bytes, so the walk that produces the
/// map stays at the edge and every rule below is testable with no disk.
class SkillValidator {
  const SkillValidator({this.reservedNames = const {}});

  /// Names no artifact may take, lowercased, with the reason (R6.11).
  final Map<String, String> reservedNames;

  static final _namePattern = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');
  static final _semver = RegExp(r'^\d+\.\d+\.\d+([-+][0-9A-Za-z.-]+)?$');

  ValidationResult validate({
    required String directoryName,
    required Map<String, Uint8List> tree,
  }) {
    final findings = <Finding>[];

    // R13.3 — a separate skill.yaml is prohibited: it would create a second
    // source of truth for facts SKILL.md already carries.
    for (final path in tree.keys) {
      if (path.toLowerCase() == 'skill.yaml' || path.toLowerCase() == 'skill.yml') {
        findings.add(const Finding('R13.3', 'a separate skill.yaml is prohibited'));
      }
    }

    final source = tree['SKILL.md'];
    if (source == null) {
      findings.add(const Finding('13.1', 'no SKILL.md in the directory'));
      return ValidationResult(artifact: directoryName, findings: findings);
    }

    final reserved = reservedNames[directoryName.toLowerCase()];
    if (reserved != null) {
      findings.add(Finding('R6.11', '"$directoryName" is a reserved name: $reserved'));
    }

    final (frontmatter, parseFindings) = _parse(utf8.decode(source, allowMalformed: true));
    findings.addAll(parseFindings);
    if (frontmatter == null) {
      return ValidationResult(artifact: directoryName, findings: findings);
    }

    findings.addAll(_checkName(frontmatter.name, directoryName));
    findings.addAll(_checkDescription(frontmatter.description));
    findings.addAll(_checkCompatibility(frontmatter.compatibility));
    findings.addAll(_checkMetadata(frontmatter));

    return ValidationResult(
      artifact: directoryName,
      findings: findings,
      frontmatter: frontmatter,
    );
  }

  (SkillFrontmatter?, List<Finding>) _parse(String text) {
    final match = RegExp(r'^---\r?\n(.*?)\r?\n---\r?\n?', dotAll: true).firstMatch(text);
    if (match == null) {
      return (null, [const Finding('13.1', 'SKILL.md has no YAML frontmatter block')]);
    }

    final YamlMap doc;
    try {
      final parsed = loadYaml(match.group(1)!);
      if (parsed is! YamlMap) {
        return (null, [const Finding('13.1', 'the frontmatter is not a YAML mapping')]);
      }
      doc = parsed;
    } on YamlException catch (e) {
      return (null, [Finding('13.1', 'the frontmatter is not valid YAML: ${e.message}')]);
    }

    final findings = <Finding>[];
    final metadata = <String, String>{};
    final raw = doc['metadata'];
    if (raw != null) {
      if (raw is! YamlMap) {
        findings.add(const Finding('13.1', 'metadata must be a mapping'));
      } else {
        for (final e in raw.entries) {
          final value = e.value;
          if (value is String) {
            metadata[e.key.toString()] = value;
          } else {
            // The specification says a map from string keys to STRING values.
            // `version: 1.0` unquoted is the trap: YAML reads it as a double.
            findings.add(Finding(
              '13.1',
              'metadata.${e.key} is ${value.runtimeType}; the specification '
                  'defines metadata as a map from string keys to string values '
                  '(quote it: "$value")',
            ));
          }
        }
      }
    }

    return (
      SkillFrontmatter(
        name: doc['name'] as String?,
        description: doc['description'] as String?,
        license: doc['license'] as String?,
        compatibility: doc['compatibility'] as String?,
        metadata: metadata,
        allowedTools: doc['allowed-tools'] as String?,
      ),
      findings,
    );
  }

  List<Finding> _checkName(String? name, String directoryName) {
    if (name == null || name.isEmpty) {
      return [const Finding('13.1 name', 'required and must not be empty')];
    }
    final out = <Finding>[];
    if (name.length > 64) {
      out.add(Finding('13.1 name', '${name.length} characters; the maximum is 64'));
    }
    if (!_namePattern.hasMatch(name)) {
      // One message rather than five, because the pattern is one rule: lowercase
      // alphanumerics and hyphens, no leading, trailing or consecutive hyphen.
      out.add(Finding(
        '13.1 name',
        '"$name" must be lowercase alphanumerics and hyphens, with no leading, '
            'trailing or consecutive hyphen',
      ));
    }
    if (name != directoryName) {
      // Normative, and the citation R7.5 rests on: this is why a `_opencode`
      // suffix creates a second artifact rather than disambiguating one.
      out.add(Finding(
        '13.1 name',
        '"$name" must match the parent directory name "$directoryName"',
      ));
    }
    return out;
  }

  List<Finding> _checkDescription(String? description) {
    if (description == null || description.trim().isEmpty) {
      return [const Finding('13.1 description', 'required and must not be empty')];
    }
    if (description.length > 1024) {
      return [
        Finding('13.1 description',
            '${description.length} characters; the maximum is 1024'),
      ];
    }
    return const [];
  }

  List<Finding> _checkCompatibility(String? compatibility) {
    if (compatibility == null) return const [];
    if (compatibility.length > 500) {
      return [
        Finding('13.1 compatibility',
            '${compatibility.length} characters; the maximum is 500'),
      ];
    }
    // Length, and nothing else. R13.9 forbids parsing it into a rule.
    return const [];
  }

  List<Finding> _checkMetadata(SkillFrontmatter f) {
    final out = <Finding>[];

    // R13.7 — license is the top-level field. Accepting it in both places would
    // recreate the two-sources-of-truth problem R13.3 exists to prevent.
    if (f.metadata.containsKey('license')) {
      out.add(const Finding('R13.7',
          'license belongs in the top-level frontmatter field, not in metadata'));
    }

    final version = f.version;
    if (version == null) {
      out.add(const Finding('R13.6',
          'metadata.version is required; skill list renders it as a column'));
    } else if (!_semver.hasMatch(version)) {
      out.add(Finding('R13.6', 'metadata.version "$version" is not SemVer'));
    }

    if (f.skillwireOrigin == null) {
      out.add(const Finding('R13.6',
          'metadata.skillwire-origin is required: the consumer that transports '
              'this skill'));
    }

    // Unknown keys are deliberately not a finding. The specification lets
    // clients store properties it does not define, so another tool's key is
    // that tool's business.
    return out;
  }
}
