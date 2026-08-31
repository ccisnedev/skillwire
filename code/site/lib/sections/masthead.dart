import 'package:design_system/design_system.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// What this is, and what a reader can actually get today.
///
/// The status line says what actually ships, which is now two things rather
/// than one: a binary you can install, and the packages under it. It said
/// otherwise until the CLI had releases — a page must not offer what does not
/// exist, and until this week the install command did not.
class Masthead extends StatelessComponent {
  const Masthead({super.key});

  @override
  Component build(BuildContext context) => header(classes: 'masthead', [
    h1([.text('Skillwire')]),
    p(classes: 'lead', [
      .text('The layer that lets an AI coding host execute capabilities it '
          'was never trained on.'),
    ]),
    p(classes: 'status', [
      .text('A command line, and the two Dart packages underneath it — '),
      a(href: 'https://pub.dev/packages/skillwire', [.text('skillwire 0.2.0')]),
      .text(' and '),
      a(href: 'https://pub.dev/packages/datajack', [.text('datajack 0.1.0')]),
      .text(' on pub.dev. Use the CLI, or mount the same module in your own.'),
    ]),
  ]);

  @css
  static List<StyleRule> get styles => [
    css('.masthead', [
      css('.lead').styles(
        margin: Margin.only(top: Space.step),
        color: role('ink'),
        fontSize: Type.lead,
      ),
      css('.status').styles(
        margin: Margin.only(top: Space.step),
        color: role('muted'),
        fontSize: Type.micro,
      ),
    ]),
  ];
}
