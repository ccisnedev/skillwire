import 'package:design_system/design_system.dart';
import 'package:jaspr/jaspr.dart';

import 'sections/colophon.dart';
import 'sections/embedding.dart';
import 'sections/install.dart';
import 'sections/masthead.dart';
import 'sections/problem.dart';
import 'sections/proof.dart';
import 'sections/provenance.dart';
import 'sections/rules.dart';

/// The whole site, which is one page.
///
/// It is composition and nothing else: every visual decision lives either in
/// the section that owns it or in the design system. There is no `@client`
/// annotation, because nothing here needs to run in a browser — a page that
/// ships a runtime it does not use is charging the reader for it.
class App extends StatelessComponent {
  const App({super.key});

  @override
  Component build(BuildContext context) => const Page(children: [
    Masthead(),
    Install(),
    Problem(),
    Proof(),
    Provenance(),
    Rules(),
    Embedding(),
    Colophon(),
  ]);
}
