import 'package:design_system/design_system.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// What this is, and what a reader can actually get today.
///
/// The status line is not modesty. `skillwire_cli` is unpublished, so a page
/// offering an install command for it would be advertising something that does
/// not exist — and the whole argument of this project is that a tool must not
/// claim what it does not do.
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
      .text('Two Dart packages on pub.dev — '),
      a(href: 'https://pub.dev/packages/skillwire', [.text('skillwire 0.2.0')]),
      .text(' and '),
      a(href: 'https://pub.dev/packages/datajack', [.text('datajack 0.1.0')]),
      .text('. The reference CLI is not published; what ships is the library '
          'you mount in your own.'),
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
