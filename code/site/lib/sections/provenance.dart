import 'package:design_system/design_system.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// The host matrix, with where each row came from.
///
/// Provenance is the section because it is the claim hardest to make and easiest
/// to check. A path with no source resolves to a throw rather than to a
/// directory, so the dates below are load-bearing rather than documentation.
class Provenance extends StatelessComponent {
  const Provenance({super.key});

  static const _rows = <List<String>>[
    ['Claude Code', '~/.claude/skills', '.claude/skills',
      'Anthropic documentation', '2026-08-26'],
    ['Codex', r'$CODEX_HOME/skills', '.agents/skills',
      'codex.exe 0.146.0, and OpenAI documentation', '2026-08-26'],
    ['Antigravity', '~/.gemini/config/skills', '.agents/skills',
      'Antigravity’s own bundled skill, agy-customizations', '2026-08-26'],
    ['OpenCode', '~/.config/opencode/skills', '.opencode/skills',
      'opencode.exe 1.17.10, brace glob {skill,skills}', '2026-08-26'],
    ['GitHub Copilot', '~/.copilot/skills', '.github/skills',
      'GitHub documentation', '2026-08-23'],
  ];

  @override
  Component build(BuildContext context) => Band(
    heading: 'Every path says where it came from',
    children: [
      p([
        .text('A host’s directories change. Each row carries the artifact '
            'it was read from and the date it was read. A row without them '
            'throws.'),
      ]),
      div(classes: 'scroller', [
        table([
          thead([
            tr([
              th([.text('Host')]),
              th([.text('Global')]),
              th([.text('Repository')]),
              th([.text('Read from')]),
              th([.text('On')]),
            ]),
          ]),
          tbody([
            for (final r in _rows)
              tr([
                td([.text(r[0])]),
                td([code([.text(r[1])])]),
                td([code([.text(r[2])])]),
                td([.text(r[3])]),
                td([code([.text(r[4])])]),
              ]),
          ]),
        ]),
      ]),
      p(classes: 'aside', [
        .text('Reading the hosts themselves corrected two rows: '
            'Antigravity’s roots were both wrong, and OpenCode reads two '
            'spellings of its own directory.'),
      ]),
    ],
  );

  @css
  static List<StyleRule> get styles => [
    css('.scroller').styles(overflow: const Overflow.only(x: Overflow.auto)),
    css('.aside').styles(color: role('muted'), fontSize: Type.micro),
  ];
}
