import 'package:design_system/design_system.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// The five rules, as an ordered list because they are numbered in the
/// specification and referred to by number in its error messages.
class Rules extends StatelessComponent {
  const Rules({super.key});

  static const _rules = [
    'Never destroy what the acting consumer did not deploy.',
    'Never act implicitly — no default host, scope, or artifact set.',
    'Never bypass --plan / --apply.',
    'Never let reconciliation touch the filesystem; it is a pure function.',
    'Never present an unverified path as a fact.',
  ];

  @override
  Component build(BuildContext context) => Band(
    heading: 'Five rules, and no exceptions',
    children: [
      ol(classes: 'rules', [
        for (final r in _rules) li([.text(r)]),
      ]),
      p(classes: 'aside', [
        .text('Rule 4 is the one that is mechanically enforced. '
            'Reconciliation is a pure function of what was observed, what is '
            'desired and what the ledger recorded, and a test greps the '
            'package to prove no file under it imports '),
        code([.text('dart:io')]),
        .text(' — because that is the layer where a bug destroys work '
            'somebody else did.'),
      ]),
    ],
  );

  @css
  static List<StyleRule> get styles => [
    css('.rules', [
      css('&').styles(
        maxWidth: measure,
        padding: Padding.only(left: Space.step),
        margin: Margin.zero,
      ),
      css('li').styles(margin: Margin.only(bottom: Space.tight)),
      css('li::marker').styles(color: role('seal'), fontFamily: Type.monoStack),
    ]),
    css('.aside').styles(color: role('muted'), fontSize: Type.micro),
  ];
}
