# Skillwire

> The layer that lets an AI coding host execute capabilities it was never trained on.

A skill is standardised — a folder with a `SKILL.md`, the same everywhere. A
subagent is not: every host wants a different path *and* a different file format.
Hooks are worse, and in some hosts they have no destination at all.

The `skillwire` package absorbs those differences. Define a capability once;
it resolves where that capability must land, and in which shape, for each host.

**Status:** implemented and in use. The `skillwire` package and `datajack` are on
pub.dev; `macss` and `inquiry` both mount the module. Read
[`docs/PRD.md`](docs/PRD.md) first — it is the contract.

The site is at [skillwire.ccisne.dev](https://skillwire.ccisne.dev).

---

## Supported hosts

Claude Code · Codex · Antigravity · OpenCode · GitHub Copilot

At two scopes: `global` (user-level) and `repo` (repository-level).

## Structure

```
code/
  skillwire/   # the `skillwire` package — domain, reconciliation, matrix, ledger
  datajack/    # the `datajack` package — the command-line surface over it
  site/        # skillwire.ccisne.dev, as Jaspr source rather than as output
  cli/         # `skillwire_cli` — the canonical consumer
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

The word `skillwire` names three different things. Prose always qualifies it, so
a bare mention is never left for the reader to resolve. See
[`docs/adr/0004`](docs/adr/0004-writing-the-name.md).

| Written as | Is |
|---|---|
| the `skillwire` package | the Dart library — domain, reconciliation, host matrix, ledger |
| `skillwire_cli` | the Dart package of the canonical CLI |
| the `skillwire` executable | the command, with its `sw` alias |
| Skillwire | the project: this repository, its docs, the product as a whole |
| *skillwire* (italic) | Shadowrun's cyberware, only where the name is explained |

Skillwire the project is never the actor of a rule. Every rule names the
`skillwire` package, `skillwire_cli`, or the consumer.

The module mounted in consumers is `skill`, singular.

## Not only for this CLI

The `skillwire` package is a library, and `skillwire_cli` is its first consumer,
not its only one. [`macss`](https://macss.ccisne.dev) and `inquiry` embed the same
package and gain the same `skill` module, each shipping its own skills as assets
of its own release.

See [`docs/architecture.md`](docs/architecture.md).

## The five rules

1. Never destroy what the acting consumer did not deploy.
2. Never act implicitly — no default host, scope, or artifact set.
3. Never bypass `--plan` / `--apply`.
4. Never let reconciliation touch the filesystem; it is a pure function.
5. Never present an unverified path as a fact.

## On the name

In Shadowrun, a *skillsoft* is a recorded skill and a *skillwire* is the
neuro-muscular system that lets a body run softs it never learned. The wire is
infrastructure; the softs are the payload, and they come in kinds.

The `skillwire` package is the wire.

---

Built with [MACSS](https://macss.ccisne.dev) — Modular Architecture for Comprehensive
Software Solutions.
