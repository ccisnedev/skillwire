/// Pre-rendering entry point. This site has no client half.
library;

import 'package:design_system/design_system.dart';
import 'package:jaspr/server.dart';

import 'app.dart';
import 'main.server.options.dart';

void main() {
  Jaspr.initializeApp(options: defaultServerOptions);

  runApp(
    Document(
      title: 'Skillwire — deploy agent skills to the host that will read them',
      meta: const {
        'description':
            'A Dart package that deploys agent skills and subagents into '
            'Claude Code, Codex, Antigravity, OpenCode and GitHub Copilot, '
            'resolving the path and file format each one expects.',
      },
      lang: 'en',
      styles: baseStyles(),
      body: const App(),
    ),
  );
}
