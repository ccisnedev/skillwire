import 'package:design_system/design_system.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// One transcript, verbatim.
///
/// Captured from `skillwire_cli` 0.1.0 on 2026-08-27 and pasted unedited.
class Proof extends StatelessComponent {
  const Proof({super.key});

  @override
  Component build(BuildContext context) => Band(
    heading: 'Every parameter is required',
    children: [
      p([
        code([.text('--host')]),
        .text(', '),
        code([.text('--scope')]),
        .text(', and one of '),
        code([.text('--skill')]),
        .text(', '),
        code([.text('--module')]),
        .text(' or '),
        code([.text('--all')]),
        .text('. A missing one is named.'),
      ]),
      const Terminal(
        caption: 'skillwire_cli 0.1.0 — captured 2026-08-27, unedited',
        lines: [
          Line.typed('skillwire skill list'),
          Line.printed(
            'Error: --host is required and has no default (R12.2). '
            '[missing_parameter]',
          ),
          Line.blank(),
          Line.typed('skillwire skill list --host claude --scope global'),
          Line.printed(
            'Error: --skill, --module or --all is required and has no default '
            '(R12.2). [missing_parameter]',
          ),
          Line.blank(),
          Line.typed('skillwire skill list --host claude --scope global --all'),
          Line.printed(
            'name      version  module  kind   host    scope   status  '
            'also visible from',
          ),
          Line.printed(
            '--------  -------  ------  -----  ------  ------  ------  '
            '-----------------',
          ),
          Line.printed(
            'kritik    1.0.0    core    skill  claude  global  keep    opencode',
          ),
          Line.printed(
            'legion    1.0.0    core    skill  claude  global  keep    opencode',
          ),
          Line.printed(
            'research  1.0.0    core    skill  claude  global  keep    opencode',
          ),
        ],
      ),
      p([
        .text('OpenCode reads Claude Code’s directory. A skill deployed for '
            'one answers for both, so at global scope they hold the same '
            'variant. The last column says which hosts share a directory.'),
      ]),
      p([
        .text('Every command takes '),
        code([.text('--plan')]),
        .text(' or '),
        code([.text('--apply')]),
        .text('.'),
      ]),
    ],
  );
}
