import 'package:design_system/design_system.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// Two transcripts, verbatim.
///
/// Both were captured from `skillwire_cli` 0.1.0 on 2026-08-27 and are pasted
/// unedited. A page that says a tool refuses to guess is asking to be believed;
/// a page that shows the refusal is not.
class Proof extends StatelessComponent {
  const Proof({super.key});

  @override
  Component build(BuildContext context) => Band(
    heading: 'It refuses to guess',
    children: [
      p([
        .text('There is no implicit host, no implicit scope and no implicit '
            '“everything”. Each omission is answered by naming what is '
            'missing, not by choosing on the reader’s behalf.'),
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
        .text('The last column is the part no host will tell you. OpenCode '
            'reads Claude Code’s directory, so a skill deployed for one '
            'is answering for both — and the two cannot hold different '
            'variants of it at global scope.'),
      ]),
      p([
        .text('Nothing is written without being described first, and the '
            'description is not a flag you may forget:'),
      ]),
      const Terminal(
        caption: 'skillwire_cli 0.1.0 — captured 2026-08-27, unedited',
        lines: [
          Line.typed('skillwire skill deploy --host claude --scope global --all'),
          Line.printed('Error: Choose --plan or --apply.'),
          Line.printed('  --plan   show what would change; nothing is touched'),
          Line.printed('  --apply  show it, ask for approval, then do it'),
        ],
      ),
    ],
  );
}
