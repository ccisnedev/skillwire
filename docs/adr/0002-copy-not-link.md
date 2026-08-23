# ADR 0002: Deploy by copy, not by link

**Status:** Accepted

## Context

A skill must reach the directory each host reads. Three mechanisms were available.

**Link to the consumer CLI's asset directory.** The host's directory holds a
symlink or junction pointing into the CLI's installation directory. One source of
truth, no duplication, edits propagate instantly.

**One canonical copy, links from each host.** A single materialised copy in a
Skillwire-owned directory, with a link from each host's directory to it. This is
the model `npx skills` uses. Updating one directory updates every host at once,
and a link that points into a Skillwire-owned directory is provably ours, which
makes ownership detectable without any extra bookkeeping.

**An independent copy per host.** Each host's directory receives its own real
copy of the artifact.

Three facts constrain the choice:

1. A skill belongs to a specific release of the CLI that transports it. That CLI's
   asset directory is replaced when the CLI is upgraded.
2. Subagents have no cross-host standard. Claude Code reads Markdown with YAML
   frontmatter; Codex reads a YAML file inside a plugin structure. The same
   artifact must be emitted in different shapes for different hosts.
3. Skills themselves are not perfectly portable either: `allowed-tools` is marked
   experimental in the Agent Skills specification and its syntax uses host-specific
   tool names.

## Decision

Deploy by **copying**, independently into each host's directory.

## Consequences

**Linking to the CLI's asset directory is unsafe.** Upgrading the CLI replaces
that directory, so a link would silently change what a host executes with no
deployment having occurred. What a host runs would no longer be a fact anyone
decided; it would be whatever happens to be at the other end of the link right
now. That breaks the premise that an artifact belongs to a release.

**The canonical-copy-plus-links model cannot express per-host variation.** All
hosts read the same bytes, so subagents — which require a different format per
host — are impossible under it. Fact 2 rules it out for the roadmap, not merely
for today.

**Copy makes the deployed version verifiable.** You deployed version X and it
stays X until you deploy again. Comparing the destination's content hash against
the source detects an artifact edited by hand at the destination, which becomes
state 4 of the reconciliation table.

**Copy enables per-host transformation.** Emitting a variant for one host and a
different variant for another is a change of what gets written, not a change of
architecture.

**The cost: a copy carries no proof of ownership.** With links, "is this ours?"
is answered by reading the link target. A copied directory in `~/.claude/skills/`
is indistinguishable from one written by hand, by `npx skills`, or by another
consumer CLI. Without an answer to that question, removal and orphan cleanup
would risk destroying a user's work.

This is why the ledger is not optional. It supplies the ownership fact that the
copy does not carry, and it is what makes states 4, 5 and 6 of the reconciliation
table distinguishable at all.

**Duplication is accepted.** Deploying to five hosts writes five copies of a text
file. The disk cost is irrelevant; the correctness gain is not.

**The canonical-copy model remains available later** for kinds that never need
per-host variation, should atomic multi-host updates become worth the extra
mechanism. Nothing in this decision forecloses it.
