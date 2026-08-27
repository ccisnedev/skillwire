/// The host matrix, as data (R6.3).
///
/// This file contains **no logic**. It is a YAML document in a Dart string
/// literal, and that is the whole of it: adding a host, moving a path or
/// recording a new provenance is an edit to the text below and to nothing else.
/// A `switch` on host id anywhere in `lib/` would make R6.3's promise false, and
/// `host_matrix_test.dart` checks that none appears.
///
/// It is embedded rather than shipped as a loose asset because a package
/// consumed from pub.dev has no reliable path to its own files at runtime. The
/// YAML is the source of truth either way; there is no second copy to drift.
///
/// **Every path carries provenance** — the artifact it was read from, its
/// version, and the date (R6.4, R14.2). A path with `provenance: unverified`
/// resolves to a throw, not to a directory. `~` expands to the user's home;
/// `$VAR` to an environment variable, with `fallback` used when it is unset.
library;

const hostMatrixYaml = r'''
version: 1

hosts:
  claude:
    name: Claude Code
    # Its config root. Absence means the host is not installed, so an
    # unqualified run skips it rather than creating a tree nothing reads.
    marker: "~/.claude"
    skills:
      global:
        - path: "~/.claude/skills"
          provenance:
            source: "Anthropic documentation, code.claude.com/docs/en/skills"
            read: "2026-08-26"
      repo:
        - path: ".claude/skills"
          provenance:
            source: "Anthropic documentation, code.claude.com/docs/en/skills"
            read: "2026-08-26"

  codex:
    name: Codex
    marker: "~/.codex"
    skills:
      global:
        - path: "$CODEX_HOME/skills"
          fallback: "~/.codex/skills"
          provenance:
            source: "codex.exe 0.146.0, stated in prose by the binary"
            read: "2026-08-26"
        - path: "~/.agents/skills"
          provenance:
            source: "OpenAI documentation, learn.chatgpt.com/docs/build-skills"
            read: "2026-08-26"
      repo:
        - path: ".agents/skills"
          provenance:
            source: "OpenAI documentation, learn.chatgpt.com/docs/build-skills"
            read: "2026-08-26"

  antigravity:
    name: Antigravity
    marker: "~/.gemini/antigravity-cli"
    skills:
      global:
        - path: "~/.gemini/config/skills"
          provenance:
            source: "Antigravity builtin skill agy-customizations, SKILL.md Discovery Locations"
            read: "2026-08-26"
      repo:
        - path: ".agents/skills"
          # .agent/, _agents/ and _agent/ are the same root under other
          # spellings (R6.6). Recognised when observing, never written to.
          aliases: [".agent/skills", "_agents/skills", "_agent/skills"]
          provenance:
            source: "Antigravity builtin skill agy-customizations, docs/skills.md"
            read: "2026-08-26"

  opencode:
    name: OpenCode
    marker: "~/.config/opencode"
    skills:
      global:
        # Its own tree is resolved with the brace glob {skill,skills}, so both
        # spellings are read and they are ONE destination for the one-path
        # invariant (R6.5). The plural is written; the singular is observed.
        - path: "~/.config/opencode/skills"
          aliases: ["~/.config/opencode/skill"]
          provenance:
            source: 'opencode.exe 1.17.10, constant fa="{skill,skills}/**/SKILL.md"'
            read: "2026-08-26"
      repo:
        - path: ".opencode/skills"
          aliases: [".opencode/skill"]
          provenance:
            source: 'opencode.exe 1.17.10, constant fa="{skill,skills}/**/SKILL.md"'
            read: "2026-08-26"

  copilot:
    name: GitHub Copilot
    marker: "~/.copilot"
    skills:
      global:
        - path: "~/.copilot/skills"
          provenance:
            source: "GitHub documentation"
            read: "2026-08-23"
        - path: "~/.agents/skills"
          provenance:
            source: "GitHub documentation"
            read: "2026-08-23"
      repo:
        - path: ".github/skills"
          provenance:
            source: "GitHub documentation"
            read: "2026-08-23"

# Directories a host reads that another host owns (PRD 7.1). Every edge is a
# property of the ecosystem, not a choice this package makes, and every one has
# a consequence a user cannot infer. `scope` is where the edge applies.
visibility:
  - host: opencode
    reads: "~/.claude/skills"
    scope: global
    source: "OpenCode documentation"
  - host: opencode
    reads: ".claude/skills"
    scope: repo
    source: "OpenCode documentation"
  - host: opencode
    reads: "~/.agents/skills"
    scope: global
    source: "OpenCode documentation"
  - host: opencode
    reads: ".agents/skills"
    scope: repo
    source: "OpenCode documentation"
  - host: codex
    reads: ".agents/skills"
    scope: repo
    source: "OpenAI documentation"
  - host: codex
    reads: "~/.agents/skills"
    scope: global
    source: "OpenAI documentation"
  - host: antigravity
    reads: ".agents/skills"
    scope: repo
    source: "Antigravity agy-customizations skill"
  # R7.1 — Copilot's edge to Claude's directory exists at repo scope ONLY.
  # GitHub lists ~/.copilot/skills and ~/.agents/skills as the personal
  # locations; ~/.claude/skills is not among them, and encoding a global edge
  # here would produce false warnings.
  - host: copilot
    reads: ".claude/skills"
    scope: repo
    source: "GitHub documentation"
  - host: copilot
    reads: "~/.agents/skills"
    scope: global
    source: "GitHub documentation"
  - host: copilot
    reads: ".agents/skills"
    scope: repo
    source: "GitHub documentation"

# Names no artifact may take, and why.
reserved:
  - name: synced
    reason: >-
      Claude Code reserves it in every skill location, in any capitalisation,
      for skills downloaded from claude.ai (R6.11).

# Paths a host reads that this package will never write to (R6.10).
never_destinations:
  - path: "/etc/codex/skills"
    reason: >-
      machine-wide, which is neither of the two scopes this project models
''';
