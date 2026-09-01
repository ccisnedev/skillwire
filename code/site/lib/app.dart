import 'package:design_system/design_system.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import 'sections/colophon.dart';
import 'sections/embedding.dart';
import 'sections/install.dart';
import 'sections/problem.dart';
import 'sections/proof.dart';
import 'sections/provenance.dart';
import 'sections/rules.dart';

/// The whole site, which is one page.
///
/// Composition, and nothing else. Every visual decision lives in the section
/// that owns it or in the design system. No component here is annotated
/// `@client`; the only script on the page is the six lines `Command` carries.
class App extends StatelessComponent {
  const App({super.key});

  @override
  Component build(BuildContext context) => Page(
    children: [
      Masthead(
        name: 'Skillwire',
        tagline: 'The layer that lets an AI coding host execute capabilities '
            'it was never trained on.',
        children: [
          p(classes: 'status', [
            .text('A command line, and the two Dart packages underneath it — '),
            a(href: 'https://pub.dev/packages/skillwire', [.text('skillwire 0.2.0')]),
            .text(' and '),
            a(href: 'https://pub.dev/packages/datajack', [.text('datajack 0.1.0')]),
            .text(' on pub.dev. Use the CLI, or mount the same module in your own.'),
          ]),
        ],
      ),
      const Install(),
      const Problem(),
      const Proof(),
      const Provenance(),
      const Rules(),
      const Embedding(),
      const Colophon(),
    ],
  );

  @css
  static List<StyleRule> get styles => [
    css('.status').styles(color: role('muted'), fontSize: Type.micro),
  ];
}
