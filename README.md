# skillwire

> The layer that lets an AI coding host execute capabilities it was never trained on.

A skill is standardised — a folder with a `SKILL.md`, the same everywhere. A
subagent is not: every host wants a different path *and* a different file format.
Hooks are worse, and in some hosts they have no destination at all.

Skillwire absorbs those differences. Define a capability once; the package
resolves where it must land, and in which shape, for each host.

**Status:** specification complete, implementation not started.
Read [`docs/PRD.md`](docs/PRD.md) first — it is the contract.

---

## Supported hosts

Claude Code · Codex · Antigravity · OpenCode · GitHub Copilot

At two scopes: `global` (user-level) and `repo` (repository-level).

## Structure

```
code/
  skillwire/   # the library — domain, reconciliation, host matrix, ledger
  cli/         # the canonical consumer CLI
    assets/
      skills/
        modules/
          core/        # transversal skills
          <domain>/    # topical skills
docs/
  PRD.md               # the specification
  architecture.md      # how the pieces fit
  roadmap.md
  adr/                 # why the decisions were made
```

## Names

| | |
|---|---|
| Library package | `skillwire` |
| CLI package | `skillwire_cli` |
| Executable | `skillwire`, alias `sw` |
| Module in consumers | `skill` |

## Not only for this CLI

`skillwire` is a library, and the CLI in this repository is its first consumer,
not its only one. [`macss`](https://macss.dev) and `inquiry` embed the same
package and gain the same `skill` module, each shipping its own skills as assets
of its own release.

See [`docs/architecture.md`](docs/architecture.md).

## The five rules

1. Never destroy what Skillwire did not deploy.
2. Never act implicitly — no default host, scope, or artifact set.
3. Never bypass `--plan` / `--apply`.
4. Never let reconciliation touch the filesystem; it is a pure function.
5. Never present an unverified path as a fact.

## On the name

In Shadowrun, a *skillsoft* is a recorded skill and a *skillwire* is the
neuro-muscular system that lets a body run softs it never learned. The wire is
infrastructure; the softs are the payload, and they come in kinds.

This package is the wire.

---

Built with [MACSS](https://macss.dev) — Modular Architecture for Comprehensive
Software Solutions.
