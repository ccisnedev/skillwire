# ADR 0003: The package is named `skillwire`

**Status:** Accepted

## Context

The package deploys skills today and will deploy subagents next, possibly hooks
after that. Naming it after the payload would age badly with each addition.

Descriptive candidates were considered and rejected:

- `agent_extension_manager` — "extension" is not a first-class entity in any
  host. Skills exist, subagents exist, plugins exist; an "extension" does not.
- `agent_plugin_manager` — a plugin is the *packaging* layer, a versioned bundle
  containing artifacts. It sits one level above what this package deploys, so the
  name describes the wrong level.
- `ai_host_manager` — names the destination, which is stable, but says nothing
  about what it does there.
- `skill_manager` — clear, but names only the first payload.

## Decision

The package is named **`skillwire`**, after Shadowrun's cyberware.

In that setting a *skillsoft* is a recorded skill — "a programmed skill, which
allows users to know and do things they never otherwise learned". A *skillwire*
is the neuro-muscular system that lets a body interface with those chips and run
them.

## Consequences

**The name describes the infrastructure, not the cargo.** A *skillwire* runs
activesofts, and with the right link, knowsofts and linguasofts too: one system,
several kinds of payload. That is exactly the resolver signature
`(host, subagent?, kind, scope)`. The `skill` inside the word names the wire's
purpose, not a restriction on what travels through it.

**The taxonomy is available for later use.** `activesoft`, `knowsoft`,
`simsense` and `datajack` are all unclaimed on pub.dev. If sub-packages or
internal concepts need names, a coherent vocabulary already exists rather than
having to be invented.

**It is allegorical, not descriptive.** A newcomer will not deduce the package's
function from its name, and the README must therefore state it in the first line.
That cost is accepted: a descriptive name that must be replaced when subagents
arrive is worse than an evocative one that never has to change.

**The executable keeps a short alias.** The `skillwire` executable is long to
type, so `sw` is provided.

**The word now names three things.** The package, `skillwire_cli` and the
executable all carry it. How each is written in prose is settled in ADR 0004.
