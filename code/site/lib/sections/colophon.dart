import 'package:design_system/design_system.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

class Colophon extends StatelessComponent {
  const Colophon({super.key});

  @override
  Component build(BuildContext context) => footer(classes: 'colophon', [
    p([
      .text('In Shadowrun a '),
      em([.text('skillsoft')]),
      .text(' is a recorded skill and a '),
      em([.text('skillwire')]),
      .text(' is the system that lets a body run softs it never learned. '
          'The wire is infrastructure; the softs are the payload.'),
    ]),
    p([
      a(href: 'https://github.com/ccisnedev/skillwire', [.text('Source')]),
      .text(' · '),
      a(href: 'https://pub.dev/packages/skillwire', [.text('skillwire')]),
      .text(' · '),
      a(href: 'https://pub.dev/packages/datajack', [.text('datajack')]),
      .text(' · built with '),
      a(href: 'https://macss.ccisne.dev', [.text('MACSS')]),
    ]),
  ]);

  @css
  static List<StyleRule> get styles => [
    css('.colophon', [
      css('&').styles(
        padding: Padding.only(top: Space.stride),
        margin: Margin.only(top: Space.chasm),
        border: Border.only(
          top: BorderSide(color: role('rule'), width: Unit.pixels(1)),
        ),
        color: role('muted'),
        fontSize: Type.micro,
      ),
      css('p').styles(margin: Margin.only(bottom: Space.snug)),
    ]),
  ];
}
