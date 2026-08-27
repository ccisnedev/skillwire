import 'package:design_system/design_system.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

class Problem extends StatelessComponent {
  const Problem({super.key});

  @override
  Component build(BuildContext context) => const Band(
    heading: 'One capability, five destinations',
    children: [
      _Body(),
    ],
  );
}

class _Body extends StatelessComponent {
  const _Body();

  @override
  Component build(BuildContext context) => Component.fragment([
    p([
      .text('A skill is standardised: a directory holding a '),
      code([.text('SKILL.md')]),
      .text(', the same everywhere. A subagent is not. Every host wants a '
          'different path '),
      em([.text('and')]),
      .text(' a different file format, and hooks are worse — in some hosts '
          'they have no destination at all.'),
    ]),
    p([
      .text('The '),
      code([.text('skillwire')]),
      .text(' package absorbs the difference. A capability is defined once, '
          'and the package resolves where it must land and in what shape for '
          'each host it is asked about.'),
    ]),
  ]);
}
