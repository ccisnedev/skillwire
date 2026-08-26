# datajack

> The command-line surface of the [`skillwire`](https://pub.dev/packages/skillwire)
> package: a `skill` module of five routes that any `modular_cli_sdk` CLI mounts
> to deploy agent skills into AI coding hosts.

In Shadowrun a *datajack* is the port through which a person connects to a
device. The wire moves the skills; this is where a human plugs in to govern it.

## Mount it

```dart
cli.module('skill', (m) => buildSkillModule(
  m,
  consumer: 'macss',      // written into every ledger row this CLI creates
  workspace: workspace,
  catalogue: catalogue,
));
```

That is the whole integration. `consumer` is what makes a shared machine work:
the ledger records who deployed what, so a second CLI meeting your artifact
reports it as owned rather than overwriting it.

## The five routes

| Route | Kind | |
|---|---|---|
| `skill list` | Query | Catalogue and status in one table, with what else can see it |
| `skill deploy` | Command | Reconcile a host toward the skills this release ships |
| `skill remove` | Command | Reconcile away from them, touching only what this consumer deployed |
| `skill doctor` | Query | What is deployed, who owns it, what has drifted |
| `skill validate` | Query | Conformance to the Agent Skills specification |

Every Command requires `--plan` or `--apply`; neither is a default. `--host` and
`--scope` are required and have no defaults either.

## Why a separate package

Because it is irreducibly a command-line surface, and the domain is not. It
declares `--host` and `--scope`, maps failures onto exit codes, and renders an
aligned table for a terminal — none of which survives a move to another
transport, and none of which belongs in a library about reconciling directories.

Keeping them apart also keeps `skillwire` off the SDK's release cadence: were
the domain to depend on `modular_cli_sdk`, it would become the gate through
which every consumer reaches a new SDK version.

See [ADR 0005](https://github.com/ccisnedev/skillwire/blob/main/docs/adr/0005-the-cyberware-vocabulary.md).

---

Built with [MACSS](https://macss.dev).
