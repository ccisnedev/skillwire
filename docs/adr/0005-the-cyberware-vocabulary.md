# ADR 0005: The CLI module is a separate package, named `datajack`

**Status:** Accepted

## Context

The `skillwire` package holds the domain: reconciliation, the host matrix, the
ledger, diagnosis. Consumers reach it through a `skill` module of five routes.
The question was where that module lives, given R12.8 keeps the package off
`modular_cli_sdk`.

Three answers were considered, and the choice was made from measurement rather
than from the rule, because R12.8 was written days earlier by the same hand and
citing it would have been circular.

### What the measurement found

The 1450 lines that looked like CLI glue are two different things:

| | Lines | |
|---|---|---|
| `Workspace`, `Catalogue`, `Planner`, `Scan` | 464 | import no SDK at all |
| The five routes, their DTOs, the parameter contract | ~995 | genuinely SDK-bound |

The first group is not glue. Reading an asset tree, resolving host paths,
scanning directories and building a desired state know nothing about flags.

The second group is **irreducibly a command-line surface**, and this is the
finding that settled it. Of the eight SDK symbols the module uses, two cannot be
made transport-neutral by any rearrangement:

- **`CliParam`** — the module declares `--host`, `--scope`, `--skill`,
  `--module`, `--all`, `--force`. That is `argv` vocabulary; the class carries
  `abbr` for short flags and a `flag`/`option`/`positional` kind. An HTTP
  surface would have a request body, not flags.
- **`ExitCode`** — "semantic exit codes for CLI commands". HTTP answers 409, not
  6.

And a third thing no class captures: `skill list` renders an aligned table for a
terminal.

### Why splitting `modular_cli_sdk` does not answer this

Only four of its twenty-two source files import `cli_router`
(`change_flags`, `declared_arguments`, `modular_cli`, `module_builder`), and no
neutral file imports a bound one — the seam is closed, and a split is
mechanically possible with no refactoring. `preview_executor` was extracted
along exactly such a seam already.

But an import graph measures imports, not meaning. Read by intent, the genuinely
transport-neutral core is around 553 lines — `Command`, `Query`, `Input`,
`Output`, `CommandException`, `plan`, `approver` — and roughly 829 more are
command-line concepts that merely happen not to import the router: `CliParam`,
`ExitCode`, the output formatters, the help renderer.

The module needs `CliParam` and `ExitCode`. They fall on the command-line side
of any honest cut, so the module would still need that half after a split.
Splitting the SDK is a good idea on its own merits and is **orthogonal to this
one**; tying them together would delay both.

## Decision

The module lives in its own package, named **`datajack`**.

```
skillwire   →  preview_executor          the wire: domain, and no flags
datajack    →  skillwire, modular_cli_sdk  the port: five routes, DDTOs, params
consumers   →  datajack                    their own skills, and a mount line
```

`Workspace`, `Catalogue`, `Planner` and `Scan` move **into `skillwire`**, where
they belong: they are domain, and the package already uses `dart:io` and `path`.

### The name

ADR 0003 reserved the vocabulary for this: "`activesoft`, `knowsoft`, `simsense`
and `datajack` are all unclaimed on pub.dev. If sub-packages or internal
concepts need names, a coherent vocabulary already exists rather than having to
be invented." Re-checked on 2026-08-26: `pub.dev/api/packages/datajack` returns
404.

In Shadowrun a *datajack* is the port through which a **person** connects to a
device. That is what this package is. The wire moves the softs; the datajack is
where a human plugs in to govern it — which is precisely what someone typing
`skill deploy --host claude` is doing.

Two descriptive alternatives were rejected:

- **`skillwire_cli_module`** — consistent with `modular_cli_sdk` and leaves room
  for a `skillwire_api_module`, but puts `skillwire_cli` and
  `skillwire_cli_module` side by side, one of which *is* a CLI and the other a
  module *for* CLIs. ADR 0004 exists because this project already decided it
  dislikes exactly that ambiguity.
- **`skillwire_terminal_module`** — unambiguous, but less accurate: the
  transport is the command line, not the terminal. A `modular_cli_sdk` CLI
  writes JSON down a pipe with no terminal anywhere, which is what
  `cli_output_json.dart` is for. The ecosystem's word is `cli`.

## Consequences

**The domain is free of the SDK's release cadence.** Had `skillwire` depended on
`modular_cli_sdk`, it would have become the gate through which all three CLIs
reach a new SDK: none could move to 0.6.0 until the domain republished. The gate
now sits on `datajack`, a small package that changes when the surface changes.

**Cyberware is the umbrella, and the vocabulary has room.** `skillwire` the
system, *skillsoft* the payload, `datajack` the port. Shadowrun's *chipjack* —
the slot a soft is inserted into — is the name available for a source of
artifacts, which is what issue #1's `fixer` would supply. Three distinct things,
three distinct words, none of them straining.

**A second package is a second publish**, and the allegory costs a line of
README: someone reading `datajack:` in a pubspec cannot deduce what it is. ADR
0003 accepted that cost for the same reason and set the same remedy — state the
function in the first line.
