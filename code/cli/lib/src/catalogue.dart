import 'dart:io' as io;
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:skillwire/skillwire.dart';

/// One skill this release transports, read from the asset tree.
class ShippedSkill {
  const ShippedSkill({
    required this.name,
    required this.module,
    required this.directory,
    required this.tree,
    required this.validation,
  });

  final String name;

  /// The module it sits in — organisational only. R13.2 makes names globally
  /// unique across all modules and all consumers precisely so that deployment
  /// can be flat while the source tree is grouped.
  final String module;

  final String directory;
  final Map<String, Uint8List> tree;
  final ValidationResult validation;

  String get version => validation.frontmatter?.version ?? '';
  String? get description => validation.frontmatter?.description;
  String? get compatibility => validation.frontmatter?.compatibility;
  bool get isValid => validation.isValid;
}

/// The skills a consumer ships, as assets of its own release (R13.4).
///
/// The package never owns skills — it receives a materialised directory and
/// resolves where it must land. This class is the consumer side of that seam:
/// it turns `assets/skills/modules/<module>/<skill>/` into materialised trees
/// and knows nothing about hosts.
class Catalogue {
  const Catalogue({required this.skills});

  final List<ShippedSkill> skills;

  /// Read `<root>/skills/modules/<module>/<skill>/`.
  factory Catalogue.read(String assetsRoot, {required SkillValidator validator}) {
    final modulesDir = io.Directory(p.join(assetsRoot, 'skills', 'modules'));
    if (!modulesDir.existsSync()) return const Catalogue(skills: []);

    final skills = <ShippedSkill>[];
    for (final moduleEntry in modulesDir.listSync().whereType<io.Directory>()) {
      final module = p.basename(moduleEntry.path);
      for (final skillEntry in moduleEntry.listSync().whereType<io.Directory>()) {
        final name = p.basename(skillEntry.path);
        final tree = readTree(skillEntry.path);
        if (tree.isEmpty) continue;
        skills.add(
          ShippedSkill(
            name: name,
            module: module,
            directory: skillEntry.path,
            tree: tree,
            validation: validator.validate(directoryName: name, tree: tree),
          ),
        );
      }
    }
    skills.sort((a, b) => a.name.compareTo(b.name));
    return Catalogue(skills: skills);
  }

  Iterable<String> get names => skills.map((s) => s.name);

  ShippedSkill? byName(String name) =>
      skills.where((s) => s.name == name).firstOrNull;

  List<ShippedSkill> inModule(String module) =>
      skills.where((s) => s.module == module).toList();

  List<String> get modules =>
      {for (final s in skills) s.module}.toList()..sort();

  /// Artifact name to version, for the ledger's `artifactVersion` (R11.3).
  Map<String, String> get versions => {
    for (final s in skills) s.name: s.version,
  };

  /// R13.2 — names must be globally unique across all modules. A module is
  /// source-tree organisation only; deployment is flat, so two modules shipping
  /// the same name would deploy one over the other.
  List<String> get duplicateNames {
    final seen = <String, int>{};
    for (final s in skills) {
      seen[s.name] = (seen[s.name] ?? 0) + 1;
    }
    return [
      for (final e in seen.entries)
        if (e.value > 1) e.key,
    ]..sort();
  }
}
