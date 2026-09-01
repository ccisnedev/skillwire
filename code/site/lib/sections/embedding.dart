import 'package:design_system/design_system.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// What a reader can actually do with this today.
class Embedding extends StatelessComponent {
  const Embedding({super.key});

  static const _mount = r'''
import 'package:datajack/datajack.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:skillwire/skillwire.dart';

final ws = Workspace.detect();

ModularCli().module(
  'skill',
  (m) => buildSkillModule(
    m,
    // Written into every ledger row this CLI creates, and the reason
    // another consumer can tell your artifacts from its own.
    consumer: 'my_cli',
    workspace: ws,
    catalogue: Catalogue.read(
      ws.assetsRoot,
      validator: SkillValidator(reservedNames: ws.matrix.reservedNames),
    ),
  ),
);
''';

  @override
  Component build(BuildContext context) => Band(
    heading: 'Mount it in your own CLI',
    children: [
      p([
        .text('The '),
        code([.text('skillwire')]),
        .text(' package is the domain and depends on no CLI framework. '),
        code([.text('datajack')]),
        .text(' is the command-line surface over it: five routes, their '
            'parameters, and their exit codes. Adding it gives your CLI a '),
        code([.text('skill')]),
        .text(' module that ships your skills.'),
      ]),
      const Terminal(
        caption: 'What to add',
        lines: [Line.typed('dart pub add datajack')],
      ),
      const Listing(caption: 'lib/my_cli.dart', source: _mount),
      p(classes: 'aside', [
        .text('All three consumers — the reference CLI, '),
        a(href: 'https://macss.ccisne.dev', [.text('macss')]),
        .text(' and inquiry — mount this same module against one ledger per '
            'machine, which is what lets each of them refuse to touch what '
            'another one deployed.'),
      ]),
    ],
  );

  @css
  static List<StyleRule> get styles => [
    css('.aside').styles(color: role('muted'), fontSize: Type.micro),
  ];
}
