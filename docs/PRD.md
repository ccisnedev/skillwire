# Skillwire — Product Requirements Document

**Status:** Draft 2 — specification complete, implementation not started
**Date:** 2026-08-26
**Owner:** ccisnedev

> **Draft 2** closes the six gaps the runbook's traceability pass found in
> Draft 1: plan annotations (7.5) give R7.6 a carrier it did not have; R10.6
> settles what `deploy --force` does to a state 6 unit; R11.3 names its two
> timestamps; R11.5 makes the ledger one shared file and says where; and R12.7
> gives the typed error hierarchy a requirement id. See
> [`docs/runbook.md`](runbook.md) §14.
>
> It then re-read the host matrix against the hosts actually installed. OpenCode
> reads **both** spellings of its own directory (6.4) — closing Q4, adding R6.5,
> and vindicating `macss` and `inquiry` alike, since neither was wrong.
> Antigravity's two paths turned out to have no provenance at all and are now
> Q5; Codex's were read from a binary twenty-six minor versions old and are now
> Q6. R6.4 generalised into the rule that made both visible: a matrix row
> without provenance in 14.1 must refuse to resolve.
>
> Finally, 12.6 settles where the package sits. It depends on
> `preview_executor` — the transport-neutral engine `modular_cli_sdk` is itself
> built on — and never on the SDK, so the `Step` it builds is the same type a
> consumer hands back (R12.8). The price of reaching past the SDK is that the
> executor becomes reachable too, and R12.9 forbids touching it: the package
> produces steps and never runs them.

---

## 1. Purpose

The `skillwire` package is the layer that lets an AI coding host execute
capabilities it was never trained on.

An Agent Skill is a portable, standardised artifact: a folder with a `SKILL.md`.
A subagent is not. Hooks are less standardised still. Every host reads them from
a different directory, at a different scope, and — for everything except skills —
in a different file format.

The `skillwire` package absorbs those differences. You define a skill or a
subagent **once**, and the package resolves where it must land, in which shape,
for each host.

> **On the name.** In Shadowrun, a *skillsoft* is a recorded skill and a
> *skillwire* is the neuro-muscular system that lets a body run softs it never
> learned. The wire is infrastructure; the softs are payload, and they come in
> kinds. The `skillwire` package is the wire.

---

## 2. Problem

| Artifact | Standardised? | Consequence |
|---|---|---|
| Skill | **Yes** — `SKILL.md`, agentskills.io | Same file everywhere; only the *path* differs |
| Subagent | **No** | Path *and* format differ per host |
| Hook | **No**, and absent in some hosts | May have no destination at all in a given host |
| MCP server | Protocol-standard | Out of scope, see 4.2 |

A person maintaining capabilities across five hosts today must know a dozen
directory paths, two scopes, at least two subagent file formats, and which hosts
silently read other hosts' directories. That knowledge is undocumented, changes
between releases, and is currently re-derived by hand every time.

---

## 3. Glossary

Terms are used in this document with exactly these meanings, and nowhere with
any other meaning. The three things the word `skillwire` names are separated in
12.1 and governed by R12.0.

| Term | Meaning |
|---|---|
| **Host** | An AI coding agent that reads capabilities from disk: Claude Code, Codex, Antigravity, OpenCode, GitHub Copilot |
| **Artifact** | A unit that is deployed into a host; has a `kind` |
| **Kind** | The type of an artifact: `skill`, `subagent`. Future: `hook` |
| **Skill** | An artifact conforming to the Agent Skills specification: a directory containing `SKILL.md` |
| **Subagent** | An artifact defining a scoped agent with its own context; format is host-specific |
| **Plugin** | A *packaging* layer — a versioned bundle shipping several artifacts as one installable unit. Orthogonal to `kind`: a plugin is a container, not a sibling |
| **Scope** | Where a deployment lands: `global` (user-level) or `repo` (repository-level) |
| **Module** | A grouping of skills in the source tree; organisational only, it does not survive deployment |
| **Layer** | A top-level directory under `code/` in a MACSS project |
| **Materialisation** | Turning a source into a directory that contains the artifact's definition file |
| **Reconciliation** | Making a host's directories match a desired set of materialised artifacts |
| **Ledger** | Machine-local record of what *is* deployed |
| **Manifest** | Repository-level, committed declaration of what a repo *wants* deployed |
| **Consumer** | A CLI that embeds the `skillwire` package: `skillwire_cli`, `macss`, `inquiry` |
| **Acting consumer** | The consumer executing the operation at hand. Ownership in the ledger, and every rule about what may be destroyed, are relative to it — never to the `skillwire` package, which all consumers share |
| **Detected host** | A host whose directories are present on this machine, whether or not it was named with `--host` |
| **Unit** | One tuple `(artifact, kind, host, scope, subagent?)`: the atom of reconciliation, defined in 10.1 |
| **Source** | Where an artifact comes from before materialisation: a local path or a git reference |
| **Drift** | A destination whose content no longer matches what the ledger records for it |

---

## 4. Scope

### 4.1 In scope

- Deploying `skill` artifacts to the five supported hosts, at `global` and `repo` scope.
- Deploying `subagent` artifacts, including format transformation per host.
- Deploying skills scoped to a specific subagent, where a host supports it.
- Reconciliation: create, update, remove, and detect drift.
- A ledger of what is deployed, and a manifest of what a repo wants deployed.
- Validation of artifacts against the Agent Skills specification.
- Reporting cross-host visibility: warning when a deployment is also readable by
  a host that was not named.

### 4.2 Out of scope

| Excluded | Reason |
|---|---|
| MCP server management | Project philosophy: a subagent drives a CLI, not an MCP. A CLI is a versioned artifact with a stable contract and no process lifecycle; a subagent driving a consumer CLI also inherits its `--plan`/`--apply` guard rails |
| A skill catalogue, search, or marketplace UI | `npx skills` covers discovery. The `skillwire` package does not compete with it. **Contested — see issue #1** |
| Support for dozens of hosts | Five hosts, in a data table. Adding a host must be data, not code |
| Exotic source resolution (GitLab, SSH, archives, download URLs) | Local path and git are sufficient |
| A "dev mode" that links to a working copy | Solved one layer down: `modular_cli_sdk` CLIs run from source with `dart run`, so the working copy *is* the asset |
| Runtime skill generation | The `skillwire` package deploys what it is given. Generation belongs to the consumer, upstream of the seam in section 8 |

---

## 5. Goals

| # | Goal | Measure |
|---|---|---|
| G1 | One definition, many hosts | A skill authored once deploys to all five hosts with no per-host source edits |
| G2 | Nothing implicit | No default host, no default scope, no default artifact set |
| G3 | Nothing destroyed | No operation ever removes an artifact that the acting consumer did not deploy |
| G4 | Reproducible | Two machines given the same manifest reach the same deployed state |
| G5 | Honest about the ecosystem | Cross-host visibility and per-host limitations are reported, never hidden |
| G6 | Shared by consumers | `macss` and `inquiry` deploy their own skills through the same `skillwire` package with no forked logic |

---

## 6. Host matrix

### 6.1 Skill paths

| Host | `global` | `repo` |
|---|---|---|
| Claude Code | `~/.claude/skills/` | `.claude/skills/` |
| Codex | `$CODEX_HOME/skills/` — default `~/.codex/skills/` | `.agents/skills/` |
| Antigravity | **unverified — see Q5** | **unverified — see Q5** |
| OpenCode | `~/.config/opencode/skill/` **·** `~/.config/opencode/skills/` · `~/.claude/skills/` · `~/.agents/skills/` | `.opencode/skill/` **·** `.opencode/skills/` · `.claude/skills/` · `.agents/skills/` |
| GitHub Copilot | `~/.copilot/skills/` · `~/.agents/skills/` | `.github/skills/` · `.claude/skills/` · `.agents/skills/` |

OpenCode's own directory exists in **both** spellings and both are read; see
6.4. Every other host names one spelling only.

**Normative requirements**

- **R6.1** Codex's global path MUST be resolved from the `CODEX_HOME` environment
  variable, falling back to `~/.codex` only when it is unset. Hardcoding
  `~/.codex` is non-conforming.
- **R6.2** Where a host lists several directories, the `skillwire` package MUST
  resolve to exactly one of them, and that choice MUST be recorded in the ledger.
- **R6.3** The host matrix MUST live in a data file, not in code. Adding a host
  is a data change.
- **R6.4** Every path in this matrix MUST carry provenance in 14.1. A row without
  it MUST be marked unverified, and resolving it MUST raise rather than return a
  path (R14.1). This is the general rule; Antigravity is currently its only
  instance, tracked as Q5.

### 6.2 Subagent paths

| Host | Path | Format |
|---|---|---|
| Claude Code | `~/.claude/agents/` · `.claude/agents/` | Markdown with YAML frontmatter |
| Codex | inside `~/.agents/plugins/<plugin>/agents/` | `openai.yaml` — see Q1 in section 14 |
| Antigravity | unknown | unknown |
| OpenCode | unknown | unknown |

This table is **incomplete and blocks subagent support only**. Skills are unaffected.

### 6.3 The neutral namespace

`.agents/skills/` and `~/.agents/skills/` are read by Codex, OpenCode and
Copilot. `~/.agents/plugins/` is used by Codex for its plugin marketplace.

Deploying into `.agents/` reaches three hosts with one copy, at the cost of
losing per-host variation, since all three read the same bytes. The `skillwire`
package MUST expose this as an explicit destination, never as a hidden optimisation.

### 6.4 OpenCode reads both spellings

OpenCode 1.17.10 resolves its **own** skill directories with a brace glob and
the external namespaces with a plain one. Both constants are recoverable from
the binary:

```
pa=".claude"   la=".agents"
Rt="skills/**/SKILL.md"           ← .claude and .agents: plural only
fa="{skill,skills}/**/SKILL.md"   ← OpenCode's own: either spelling
```

Its own help table documents the same thing in its own notation —
`` `~/.config/opencode/skill(s)/<name>/SKILL.md` `` and
`` `.opencode/skill(s)/<name>/SKILL.md` ``.

So `~/.config/opencode/skill/` and `~/.config/opencode/skills/` are not
competing candidates to choose between: they are **one destination with two
spellings, both live at once**. Neither `macss`, which writes the singular, nor
`inquiry`, which writes the plural, was wrong.

- **R6.5** The two spellings of an OpenCode directory MUST be treated as a
  single destination for the one-path invariant (7.3). Deploying the same
  artifact into both is the collision R7.5 exists to prevent, not two
  deployments — the brace glob makes both visible under the same invocation
  name.

---

## 7. Cross-host visibility

Some hosts read other hosts' directories. This is a property of the ecosystem,
not something the `skillwire` package can change, and it has consequences a user
cannot infer.

### 7.1 The graph

| Edge | Scope | Source |
|---|---|---|
| OpenCode ← `~/.claude/skills/` | global | OpenCode documentation |
| OpenCode ← `.claude/skills/` | repo | OpenCode documentation |
| OpenCode ← `~/.agents/skills/` · `.agents/skills/` | both | OpenCode documentation |
| Codex ← `.agents/skills/` | repo | Codex binary 0.120.0 |
| Copilot ← `.claude/skills/` | **repo only** | GitHub documentation |
| Copilot ← `~/.agents/skills/` · `.agents/skills/` | both | GitHub documentation |

**R7.1** Copilot's edge to Claude's directory exists at `repo` scope only.
GitHub's documentation lists `~/.copilot/skills` and `~/.agents/skills` as the
personal locations; `~/.claude/skills` is **not** among them. Encoding a global
Copilot←Claude edge would produce false warnings and is non-conforming.

### 7.2 Required reporting

- **R7.2** When a deployment lands in a directory that a *detected but unnamed*
  host also reads, the plan MUST say so.
- **R7.3** When a removal takes an artifact out of a directory that another
  detected host also reads, the plan MUST say so.
- **R7.4** Only hosts actually detected on the machine may be named in these
  messages.

### 7.3 The one-path invariant

> For each pair (artifact, host), **exactly one** of the directories that host
> reads may contain that artifact.

**R7.5** A deployment that would violate this invariant MUST be planned as
`block`. Renaming an artifact to disambiguate — for example a `_opencode`
suffix — is explicitly rejected: the Agent Skills specification requires `name`
to equal the directory name, so a suffix creates a *second artifact* with a
different invocation command, and both remain visible to the host. That is the
collision the invariant exists to prevent.

### 7.4 An irreducible limitation

At `global` scope, Claude Code and OpenCode **cannot hold different variants of
a same-named skill**, because OpenCode reads `~/.claude/skills/` and cannot be
prevented from doing so.

At `repo` scope this is avoidable: each host has a private directory, and
the `skillwire` package can resolve to `.opencode/skills/` instead of
`.claude/skills/`.

**R7.6** The acting consumer MUST state this asymmetry in the plan when it is
relevant, never silently work around it. It is carried as an annotation — see
7.5.

### 7.5 Plan annotations

Sections 7.2 and 7.4 both require the plan to state something that is *not* a
problem with the unit. The deployment is correct; the ecosystem around it has a
consequence the user cannot infer. Section 10.2 has no room for this: every unit
there resolves to exactly one state, and a unit can be `create` **and**
ambiguous at the same time.

An **annotation** is therefore a separate axis. It attaches to a unit, states a
consequence, and changes nothing about what will happen.

- **R7.7** An annotation MUST NOT change a unit's verb and MUST NOT cause
  `--apply` to refuse. A plan consisting entirely of annotated `create` units is
  a plan that applies cleanly.
- **R7.8** The annotation set MUST include at least: cross-host visibility on
  deployment (R7.2), cross-host visibility on removal (R7.3), and the global
  asymmetry of 7.4 (R7.6). The set is open; a later ecosystem fact that a user
  cannot infer becomes another annotation rather than another state.
- **R7.9** Annotations MUST be carried in the `detail` of the unit's `Preview`
  (R12.5) and surfaced in the `also visible from` column of `skill list` (12.2).
  R7.4 applies to every annotation: only hosts actually detected on the machine
  may be named.

---

## 8. The central seam

Two phases, connected by one shape, independent of each other:

```
source ──[ materialisation ]──> a directory holding the artifact ──[ reconciliation ]──> host
```

**Materialisation** turns a source into a directory. A static skill already is
one. A generated skill is produced by its generator. A subagent is produced by
transforming the neutral definition into the host's format.

**Reconciliation** makes a host's directories match a desired set of materialised
artifacts.

**R8.1** Reconciliation MUST NOT know how an artifact was materialised. This is
what allows static skills, generated skills and transformed subagents to share
one engine.

---

## 9. Deployment mechanism: copy

**R9.1** The `skillwire` package deploys by **copying** the materialised
directory into each host's directory, independently per host.

Two alternatives were considered and rejected; the rationale is recorded in
ADR 0002. In summary:

| Model | Rejected because |
|---|---|
| Link directly to the consumer's asset directory | That directory is replaced when the CLI is upgraded. An upgrade would mutate a host's behaviour with no deployment having occurred |
| One canonical copy, links from each host | Forbids per-host variation. Subagents *require* per-host transformation, so this model cannot support them |

Copy carries one cost, accepted deliberately: **a copy has no intrinsic
ownership marker.** A directory in `~/.claude/skills/` is indistinguishable from
one written by hand or by another tool. The ledger exists to supply that missing
fact, and without it section 10 cannot be implemented safely.

---

## 10. Reconciliation

### 10.1 Unit of work

One unit per tuple:

```
(artifact, kind, host, scope, subagent?)
```

### 10.2 States

Every unit resolves to exactly one of these. The verb is what appears in the plan.

| # | State found at destination | Verb | Behaviour |
|---|---|---|---|
| 1 | Nothing | `create` | Deploy |
| 2 | Deployed by the acting consumer, content hash matches | `keep` | No action |
| 3 | Deployed by the acting consumer, content hash differs | `replace` | Deploy; plan shows `old → new` |
| 4 | Deployed by the acting consumer, modified at the destination | `block` | Local edits would be lost |
| 5 | Deployed by a different consumer | `block` | Plan names the owning consumer |
| 6 | Present but absent from the ledger | `block` | No consumer deployed it; `--force` may adopt it — R10.6 |

- **R10.1** A plan containing any `block` MUST cause `--apply` to refuse, unless
  `--force` is passed.
- **R10.2** `--force` MUST NOT be implied by any other flag.
- **R10.3** `remove` MUST act only on states 2, 3 and 4. States 5 and 6 are never
  removed, with or without `--force`.
- **R10.4** Reconciliation MUST be a pure function of `(observed state, desired
  state)`. Filesystem access belongs at the edges: one read before, one write
  after. This makes every row of this table unit-testable with no disk.
- **R10.5** Reconciliation MUST be idempotent: applying the same plan twice
  produces `keep` for every unit on the second run.
- **R10.6** `deploy` under `--force` MUST **adopt** a state 6 unit whose
  destination content hash equals the materialised artifact's: the ledger gains
  an entry naming the acting consumer, and **nothing is written to the
  destination**. The plan verb is `adopt`. Where the hashes differ the unit
  stays `block`, with or without `--force`. Adoption is the only circumstance in
  which an artifact no consumer deployed becomes ledgered, and it is the
  mechanism by which a machine carrying pre-package deployments migrates without
  a single byte being destroyed.

Adoption exists because of a fact about the world, not a convenience: `macss`
and `inquiry` deployed skills before any ledger existed, so on every machine
that ran them the first reconciliation finds state 6 everywhere. Rule 1 forbids
overwriting those directories and R10.3 forbids removing them; without R10.6 the
only remaining route would be a manual deletion, which is rule 1 violated by the
user's own hand on the tool's advice.

---

## 11. State: ledger and manifest

Two files, two different questions, following the `package.json` /
`package-lock.json` split.

| | Manifest | Ledger |
|---|---|---|
| Answers | what this repo *wants* deployed | what *is* deployed on this machine |
| Location | repository root | `$SKILLWIRE_HOME/ledger.json`, default `~/.skillwire/ledger.json` — R11.5 |
| Committed | **yes** | no |
| Written by | a human, or a consumer CLI | a consumer CLI only |
| How many | one per repository | **one per machine, shared by every consumer** — R11.5 |

- **R11.1** The `skillwire` package MUST NOT read or write
  `~/.agents/.skill-lock.json`. That file belongs to `npx skills`, whose
  implementation **deletes it outright** when it encounters a version lower than
  its current one. Sharing it would mean
  losing the ledger on an unrelated tool's upgrade.
- **R11.2** The ledger key MUST be the full tuple of 10.1. `npx skills` keys by
  skill name alone and records no per-host state; that shape cannot express the
  model of the `skillwire` package.
- **R11.3** The ledger MUST record, per unit: source type, source reference,
  resolved destination path, content hash, owning consumer, artifact version,
  and two timestamps — **`created`**, when the acting consumer first deployed or
  adopted the unit, and **`updated`**, when it last wrote to the destination.
  `keep` advances neither; `adopt` (R10.6) sets both to the same instant, since
  no write to the destination occurred.
- **R11.4** Paths stored in the manifest MUST be relative and use `/` separators,
  so a manifest is portable across machines and operating systems.
- **R11.5** There MUST be exactly **one ledger per machine**, shared by every
  consumer, at `$SKILLWIRE_HOME/ledger.json` — falling back to
  `~/.skillwire/ledger.json` only when `SKILLWIRE_HOME` is unset, the same
  resolution rule R6.1 applies to `CODEX_HOME`. A ledger per consumer is
  non-conforming: state 5 asks *which other consumer owns this*, and a consumer
  that can only read its own ledger cannot answer it without reading files it
  has no contract with — and cannot answer it at all for a consumer it has never
  heard of.
- **R11.6** The ledger MUST carry a schema version, and every write MUST be
  atomic: serialise to a temporary file in the same directory, then rename over
  the target. Three CLIs share this file, so a write interrupted midway would
  leave the other two unable to tell what they own — which is rule 1 lost to a
  power cut.

---

## 12. CLI contract

### 12.1 Identity

| | Value | Written in prose as |
|---|---|---|
| Dart package, library | `skillwire` | the `skillwire` package |
| Dart package, CLI | `skillwire_cli` | `skillwire_cli` |
| Executable | `skillwire` | the `skillwire` executable |
| Alias | `sw` | the `sw` alias |
| Module mounted in consumers | `skill`, singular | the `skill` module |

**R12.0** One name identifies one thing. The word `skillwire` identifies three,
so every mention in prose MUST carry the qualifier in the third column; a bare
`skillwire` in prose is non-conforming. *Skillwire* capitalised names the
project and MUST NOT be the subject of a requirement — a requirement names the
`skillwire` package, `skillwire_cli`, or the consumer. Recorded in ADR 0004.

**R12.1** The module is named `skill`, singular, in every consumer. `macss`
already ships `skill list|deploy|clean` for its lifecycle skills; those routes
are absorbed by this module, with lifecycle skills becoming one source among
others. Two modules differing by a single `s` are prohibited.

### 12.2 Routes

Routes follow `modular_cli_sdk`: a **Query** reads and answers and rejects
`--plan`/`--apply`; a **Command** changes something and must declare which.

| Route | Type | Purpose |
|---|---|---|
| `skill list` | Query | Catalogue and status in one table |
| `skill deploy` | Command | Reconcile toward a desired state |
| `skill remove` | Command | Reconcile away from it |
| `skill doctor` | Query | Diagnose drift without mutating |
| `skill validate` | Query | Conformance of sources to the specification |

`skill list` columns: **name · version · module · kind · host · scope · status ·
also visible from**.

The last column is section 7 made visible: it names detected hosts that read the
destination without having been targeted.

### 12.3 Parameters

| Parameter | Values | Required |
|---|---|---|
| `--host` | `claude` · `codex` · `antigravity` · `opencode` · `copilot` | **yes**, repeatable |
| `--scope` | `global` · `repo` | **yes** |
| `--skill` | artifact name | exactly one of these three |
| `--module` | module name | exactly one of these three |
| `--all` | — | exactly one of these three |
| `--force` | — | no |

- **R12.2** There is no implicit "all hosts" and no default scope. Omitting a
  required parameter is an error, never a default.
- **R12.3** `--scope=repo` outside a repository MUST fail explicitly. It MUST NOT
  fall back to `global`.
- **R12.4** Every Command MUST require `--plan` or `--apply`. `modular_cli_sdk`
  enforces this, and neither the `skillwire` package nor any consumer may bypass
  it.

### 12.4 Steps

- **R12.5** Each unit of 10.1 is emitted as one `Step`. `preview()` returns the
  verb of 10.2 and carries the unit's annotations (7.5) in its detail;
  `perform()` does the work. The two are separate methods, never one method
  behind a dry-run flag — a flag threaded through the work leaves nothing holding
  the switched-off pass and the real one to the same behaviour.
- **R12.6** The `skillwire` package MUST NOT define a plan type of its own. The
  plan is the ordered list of Steps, and `modular_cli_sdk` renders and approves it.

### 12.5 Errors

- **R12.7** The `skillwire` package MUST define a typed error hierarchy rooted in
  a single sealed type, which the consumer maps onto `modular_cli_sdk`'s exit
  codes. Every condition a caller must distinguish gets its own type — at
  minimum a missing or omitted parameter (R12.2), `--scope=repo` outside a
  repository (R12.3), and an unverified path refused under R14.1. A consumer
  MUST NOT have to match on message text to decide what happened.

### 12.6 Where the package sits

- **R12.8** The `skillwire` package MUST depend on `preview_executor`, **not** on
  `modular_cli_sdk`. It needs the vocabulary for stating a change before making
  it — `Step`, `Preview`, `Outcome`, `StepContext` — and nothing above it. The
  SDK re-exports those four from `preview_executor`, so the `Step` the package
  builds is the same type a consumer's `Command.steps()` returns; a package of
  its own would need an adapter, and an adapter is where preview and perform
  come apart again.
- **R12.9** The `skillwire` package MUST NOT use `PreviewExecutor`, though
  depending on `preview_executor` puts it within reach. `modular_cli_sdk`
  withholds that class from command authors on the grounds that a command able
  to reach the executor could run steps with no plan rendered, no approval
  taken, and no check that what happened is what was announced. The package is
  in the same position and inherits the same prohibition: it **produces** steps
  and never runs them. This is non-negotiable rule 3 at the layer below the
  flag.

---

## 13. Source layout

Skills ship as assets of the CLI that transports them, because a skill is part
of a specific release of that CLI:

```
code/cli/assets/skills/modules/
├── core/          transversal — used in any context
│   ├── legion/
│   ├── kritik/
│   └── research/
└── <domain>/      topical — deployed only where relevant
    └── <skill>/
```

- **R13.1** Modules group by **generality**, not by topic. A skill usable across
  domains belongs in `core`. This is what makes "what do I deploy here?"
  answerable: `core`, plus the domains in play.
- **R13.2** Artifact names MUST be globally unique across all modules and all
  consumers. A module is source-tree organisation only; deployment is flat.
- **R13.3** Version and provenance live in the `metadata` map of the `SKILL.md`
  frontmatter, which the specification defines as a string→string map. A separate
  `skill.yaml` is prohibited: it would create a second source of truth for the
  same fact. `CHANGELOG.md` is permitted, as the specification does not cover it.
- **R13.4** Every consumer holds its own skills under its own
  `assets/skills/modules/`. There is no shared skill directory across consumers,
  and no build step copying skills between layers.
- **R13.5** Conforming to `SKILL.md` is sufficient compatibility with the wider
  ecosystem. Discoverability by any particular third-party installer is a
  courtesy, never a requirement, and MUST NOT constrain this layout.

---

## 14. Verified facts and open questions

This section exists so that no reader mistakes an assumption for a fact.

### 14.1 Verified

Every row carries the artifact it was read from and the date it was read. A row
without a date is a claim about a version nobody recorded, which is how a
verified fact quietly becomes a stale one.

| Fact | How | Read |
|---|---|---|
| Codex skill paths: `CODEX_HOME/skills`, `~/.codex/skills`, `.agents/skills` | String extraction from `codex.exe` **0.120.0** | 2026-08-23 |
| Codex watches skill directories for changes | `skills_watcher` symbol in the same binary | 2026-08-23 |
| Copilot skill paths, and that `~/.claude/skills` is not among the personal ones | GitHub official documentation | 2026-08-23 |
| OpenCode reads Claude's and `.agents`' directories, plural spelling only | Constants `pa=".claude"`, `la=".agents"`, `Rt="skills/**/SKILL.md"` in `opencode.exe` **1.17.10** | 2026-08-26 |
| **OpenCode reads its own directory in both spellings** | Constant `fa="{skill,skills}/**/SKILL.md"` in the same binary, and its help table's `skill(s)` notation — see 6.4 | 2026-08-26 |
| `npx skills` installs a whole module directory from a URL | Executed against a public repository with a nested layout | 2026-08-23 |
| `npx skills` keeps two lock files and emits install telemetry | Source files `skill-lock.ts`, `local-lock.ts`, `telemetry.ts` | 2026-08-23 |
| Windows junctions require no elevation | Executed locally | 2026-08-23 |

- **R14.2** A row in this table MUST name the artifact and version it was read
  from, and the date. When a host's installed version overtakes the version a
  row cites, the row is **unverified again** until re-read. The machine that
  wrote this document carries `codex-cli` **0.146.0**, twenty-six minor versions
  past the row above; re-reading it is P2 work, tracked as Q6.

### 14.2 Open

| # | Question | Blocks |
|---|---|---|
| Q1 | Codex subagent format: the binary shows `agents/openai.yaml` inside `~/.agents/plugins/`; a secondary source reports TOML in `~/.codex/agents/`. Both may exist | Subagents |
| Q2 | Subagent paths and formats for Antigravity and OpenCode | Subagents |
| Q3 | Whether hooks have any destination in hosts other than Claude Code | Hooks |
| Q5 | Antigravity's skill paths. 6.1 carried `~/.gemini/antigravity/skills/` and `.agent/skills/` with no provenance in 14.1. The installed layout is `~/.gemini/antigravity-cli/`, whose only skills live in `builtin/skills/` — five of them, each a `SKILL.md` beside a `docs/` directory. No user-extensible directory was found | **Antigravity, both scopes** |
| Q6 | Whether Codex's paths still hold at `codex-cli` 0.146.0. 14.1's row was read from 0.120.0, and `~/.codex/plugins/` now exists on the author's machine — the location 6.2 associates with Q1 | Codex, and Q1 with it |

**Q4 is closed.** OpenCode reads both spellings of its own directory; see 6.4
and the two 14.1 rows dated 2026-08-26.

Q1–Q3 block features not yet built. **Q5 and Q6 block hosts in a shipped
phase**, and are the open questions on the critical path: P2 cannot honestly
report a destination it cannot source, and P3 cannot deploy to one. Closing
either means reading the host itself — its binary, its source, or its official
documentation — never inferring from what happens to be on disk. Q4 is the
worked example: what was on disk showed two directories and suggested a choice;
the binary showed there was no choice to make.

**R14.1** No requirement in this document may be implemented on the basis of an
unverified path. Q1–Q3, Q5 and Q6 MUST be resolved against the hosts themselves
— their CLIs, their source, or their official documentation — before the
corresponding feature is built.

---

## 15. Phases

| Phase | Contents | Exit criterion |
|---|---|---|
| **P0** | This specification | Reviewed; no open contradictions |
| **P1** | Domain model, pure reconciliation, typed error hierarchy (R12.7) | Every row of 10.2 unit-tested with no filesystem |
| **P2** | Host matrix, host detection, visibility graph, annotations (7.5) | `skill list` and `skill doctor` correct on a real machine; Q5 and Q6 closed |
| **P3** | `skill deploy` / `skill remove`, ledger, manifest, adoption (R10.6) | Idempotent; every `block` state reproducible in a test |
| **P4** | `skillwire_cli`: the `skillwire` executable and its `sw` alias | Self-hosting: this repo's own skills deploy through it |
| **P5** | Adoption by `macss` and `inquiry` | Both consume the `skillwire` package; no forked deployment logic remains |
| **P6** | Subagents | Only after Q1 and Q2 are closed |

**R15.1** `kind` and `subagent` MUST be present in the resolver signature and in
the ledger key from P1, even though only `skill` is implemented. Adding either
later would change the ledger key, the reconciliation signature and the manifest
schema simultaneously.

---

## 16. Non-negotiables

The five rules that override any later convenience:

1. **Never destroy what the acting consumer did not deploy.** — G3, R10.3
2. **Never act implicitly.** No default host, scope, or artifact set. — G2, R12.2
3. **Never bypass plan/apply.** — R12.4
4. **Never let reconciliation touch the filesystem.** Pure function, I/O at the
   edges. — R10.4
5. **Never present an unverified path as a fact.** — R14.1
