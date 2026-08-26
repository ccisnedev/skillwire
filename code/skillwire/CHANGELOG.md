# Changelog

## 0.1.0

First working release: the domain model, reconciliation as a pure function, the
host matrix, the ledger, and validation against the Agent Skills specification.

**Reconciliation is a pure function of two values.** `reconcile(operation,
observed, desired, actingConsumer, force)` returns a plan whose steps carry a
verb decided at construction. No filesystem, no clock, no environment — I/O
lives at the edges, one read before and one write after. That is what makes
every row of the specification's state table testable without a disk, which
matters because it is the layer where a bug destroys a user's work.

**Six states, and what each protects.** Nothing at the destination creates;
ours-and-matching keeps; ours-and-differing replaces. The other three block:
ours-but-edited, because those edits are not ours to lose; another consumer's,
because it is not ours at all; and present-but-unrecorded, because nobody
claimed it. `--force` lifts the refusal of a *plan*, never the block on a
*unit*.

**Adoption.** A forced deploy over an unrecorded destination whose contents
already match writes a ledger row and **nothing to the destination**. It is how
a machine carrying deployments from before this package existed becomes managed
without a byte being destroyed. A differing hash stays blocked either way.

**The host matrix is data.** Claude Code, Codex, Antigravity, OpenCode and
GitHub Copilot, at user and repository scope, in a YAML document with no
per-host branching anywhere in the library: adding a host is an edit to that
document. Every path carries the artifact it was read from and the date, and a
path without provenance throws rather than resolving — a path handed to a caller
who will write to it has been presented as a fact.

**The ledger.** One per machine, shared by every consumer, at
`$SKILLWIRE_HOME/ledger.json`. Shared rather than per-consumer because the
question "which other consumer owns this?" cannot be answered by a book that
only records your own entries. Deployment is by copy, and a copy carries no
proof of who made it; the ledger is what supplies the fact the copy destroys.

**Diagnosis.** Classifies a machine against the ledger: intact, missing,
drifted, owned by another consumer, plus occupants nobody recorded and artifacts
one host can see from two directories.

Depends on `preview_executor` and never on `modular_cli_sdk`, which re-exports
the same `Step`, `Preview` and `Outcome` — so a step this package builds is the
type a consumer's command hands back, with no adapter between them. It
**produces** steps and never runs them.

## 0.0.1

Name reservation. No implementation yet.

The specification this package will implement lives in the repository, at
[`docs/PRD.md`](https://github.com/ccisnedev/skillwire/blob/main/docs/PRD.md).
Implementation begins at phase P1: the domain model and reconciliation as a
pure function.
