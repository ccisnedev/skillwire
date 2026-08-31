import 'package:design_system/design_system.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// How to get it.
///
/// These are `Listing`s and not `Terminal`s, and the distinction the design
/// system already draws is what decided it: a transcript says *this happened*
/// and carries a prompt mark, a listing says *write this* and carries none. An
/// install command is the second. It also sidesteps a small lie — a `$` in
/// front of a PowerShell command is a prompt that machine never shows.
class Install extends StatelessComponent {
  const Install({super.key});

  @override
  Component build(BuildContext context) => Band(
    heading: 'Install',
    children: [
      const Listing(
        caption: 'Windows · PowerShell',
        source: 'irm https://skillwire.ccisne.dev/install.ps1 | iex\n',
      ),
      const Listing(
        caption: 'Linux · bash',
        source: 'curl -fsSL https://skillwire.ccisne.dev/install.sh | bash\n',
      ),
      p([
        .text('Both fetch the latest release, unpack it into '),
        code([.text(r'%LOCALAPPDATA%\skillwire')]),
        .text(' or '),
        code([.text('~/.skillwire')]),
        .text(', add it to your PATH and create the '),
        code([.text('sw')]),
        .text(' alias. There is no macOS build yet.'),
      ]),
      p(classes: 'aside', [
        .text('Read them before you run them — '),
        a(href: 'https://skillwire.ccisne.dev/install.ps1', [.text('install.ps1')]),
        .text(', '),
        a(href: 'https://skillwire.ccisne.dev/install.sh', [.text('install.sh')]),
        .text('. Piping a script from the internet into a shell is worth that '
            'minute, here as anywhere.'),
      ]),
      p([
        .text('Then, from anywhere:'),
      ]),
      const Terminal(
        caption: 'the first thing worth running',
        lines: [
          Line.typed('skillwire skill list --host claude --scope global --all'),
        ],
      ),
    ],
  );

  @css
  static List<StyleRule> get styles => [
    css('.aside').styles(color: role('muted'), fontSize: Type.micro),
  ];
}
