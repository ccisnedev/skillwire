import 'package:path/path.dart' as p;
import 'package:skillwire/skillwire.dart';
import 'package:test/test.dart';

void main() {
  final matrix = HostMatrix.builtIn();

  PathResolver resolver({
    Map<String, String> env = const {},
    String? repo = '/repo',
  }) => PathResolver(
    home: '/home/x',
    environment: env,
    repositoryRoot: repo,
  );

  String norm(String s) => p.normalize(s).replaceAll(r'\', '/');

  group('expansion', () {
    test('~ becomes the home directory', () {
      expect(norm(resolver().expand('~/.claude/skills')!), '/home/x/.claude/skills');
    });

    test('a plain relative path is left alone', () {
      expect(resolver().expand('.claude/skills'), '.claude/skills');
    });

    test('an absolute path is left alone', () {
      expect(resolver().expand('/etc/codex/skills'), '/etc/codex/skills');
    });
  });

  group('R6.1 - CODEX_HOME and its fallback', () {
    test('the variable is used when it is set', () {
      final r = resolver(env: {'CODEX_HOME': '/opt/codex'});
      expect(norm(r.destinationFor(matrix, 'codex', Scope.global)), '/opt/codex/skills');
    });

    test('the fallback is used when it is unset', () {
      expect(
        norm(resolver().destinationFor(matrix, 'codex', Scope.global)),
        '/home/x/.codex/skills',
      );
    });

    test('an empty variable counts as unset', () {
      final r = resolver(env: {'CODEX_HOME': ''});
      expect(norm(r.destinationFor(matrix, 'codex', Scope.global)),
          '/home/x/.codex/skills');
    });

    test('the fallback is itself expanded, not returned raw', () {
      expect(resolver().expand(r'$NOPE/skills', fallback: '~/.codex/skills'),
          isNot(startsWith('~')));
    });

    test('an unset variable with no fallback resolves to null', () {
      expect(resolver().expand(r'$NOPE/skills'), isNull);
    });
  });

  group('R6.8 and R12.3 - repo scope', () {
    test('resolves against the repository root', () {
      expect(
        norm(resolver().destinationFor(matrix, 'claude', Scope.repo)),
        '/repo/.claude/skills',
      );
    });

    test('outside a repository it throws rather than falling back to global', () {
      // Silently deploying to a user's home when they asked for a project is
      // exactly the surprise rule 2 exists to prevent.
      expect(
        () => resolver(repo: null).destinationFor(matrix, 'claude', Scope.repo),
        throwsA(isA<RepoScopeOutsideRepository>()),
      );
    });

    test('the throw names where the search started, so it is actionable', () {
      try {
        resolver(repo: null).destinationFor(matrix, 'claude', Scope.repo);
        fail('expected a throw');
      } on RepoScopeOutsideRepository catch (e) {
        expect(e.startedFrom, isNotEmpty);
        expect(e.code, 'repo_scope_outside_repository');
      }
    });
  });

  group('R6.9 - observation is wider than the destination', () {
    test('OpenCode observes both spellings, absolute', () {
      final observed = resolver()
          .observedFor(matrix, 'opencode', Scope.global)
          .map(norm)
          .toList();
      expect(observed, contains('/home/x/.config/opencode/skills'));
      expect(observed, contains('/home/x/.config/opencode/skill'));
    });

    test('Antigravity observes all four repo spellings', () {
      final observed =
          resolver().observedFor(matrix, 'antigravity', Scope.repo).map(norm);
      expect(observed, containsAll([
        '/repo/.agents/skills',
        '/repo/.agent/skills',
        '/repo/_agents/skills',
        '/repo/_agent/skills',
      ]));
    });

    test('a template whose variable is unset is skipped, not crashed on', () {
      // Codex's global list is $CODEX_HOME/skills plus ~/.agents/skills. With
      // the variable unset the first still resolves through its fallback.
      expect(resolver().observedFor(matrix, 'codex', Scope.global), isNotEmpty);
    });
  });

  group('R7.4 - detection', () {
    HostDetector detector(Set<String> present) => HostDetector(
      matrix: matrix,
      resolver: resolver(),
      directoryExists: (path) => present.any((m) => norm(path).endsWith(m)),
    );

    test('a host whose marker is present is detected', () {
      expect(detector({'.claude'}).detect(), {'claude'});
    });

    test('a host whose marker is absent is not', () {
      expect(detector({}).detect(), isEmpty);
    });

    test('several hosts detect independently', () {
      expect(detector({'.claude', '.codex'}).detect(), {'claude', 'codex'});
    });

    test('detection keys on the config root, not the skills directory', () {
      // A tool installed but never given a skill still reads its skills
      // directory, so warning about it is correct. Creating that directory to
      // find out is not.
      expect(detector({'.config/opencode'}).detect(), contains('opencode'));
    });
  });
}
