# Roadmap

Phases are defined in [`PRD.md`](PRD.md) section 15. Each one lists its exit
criterion; a phase is not done until that criterion is met.

[`runbook.md`](runbook.md) is the executable form of this list: 63 numbered
stages, each with a mechanically verifiable exit criterion.

## P0 — Specification

- [x] Host matrix verified against the hosts themselves, **except Codex at its
      installed version — see Q6**
- [x] Cross-host visibility graph
- [x] Deployment mechanism decided and recorded (ADR 0002)
- [x] Reconciliation states enumerated
- [x] Ledger and manifest split defined
- [x] CLI contract defined
- [x] Name decided and recorded (ADR 0003)
- [x] How the name is written decided and recorded (ADR 0004)
- [x] Reviewed against the runbook's traceability pass; six gaps found and four
      closed in Draft 2 (annotations, adoption, the ledger's home, the error
      hierarchy)
- [ ] Reviewed

## P1 — Domain and reconciliation

- [ ] Domain model, with `kind` and `subagent` in the resolver signature
- [ ] Typed error hierarchy, sealed root (R12.7)
- [ ] `plan(observed, desired)` as a pure function
- [ ] Every reconciliation state unit-tested with no filesystem, adoption
      included (R10.6)

## P2 — Hosts

- [ ] **Q6 closed: Codex re-read at 0.146.0.** The recorded row came from
      0.120.0; blocks Codex, and bears on Q1
- [ ] Host matrix as a data file
- [ ] Host detection
- [ ] Visibility graph and its reporting, carried as plan annotations (§7.5)
- [ ] `skill list` and `skill doctor`

## P3 — Deployment

- [ ] `skill deploy` and `skill remove` as Steps
- [ ] Ledger — one per machine, shared by every consumer (R11.5, R11.6)
- [ ] Adoption of pre-package deployments (R10.6)
- [ ] Manifest
- [ ] Idempotence and every `block` state covered by a test

## P4 — `skillwire_cli`

- [ ] The `skillwire` executable with its `sw` alias
- [ ] Self-hosting: this repository deploys its own skills through it

## P5 — Adoption

- [ ] `macss` consumes the `skillwire` package
- [ ] `inquiry` consumes the `skillwire` package
- [ ] `inquiry`'s `clean()` narrowed to what it actually wrote — it deletes ten
      host directories wholesale today
- [ ] The three transversal skills moved out of `inquiry` into `skillwire_cli`
- [ ] No forked deployment logic left in either

## P6 — Subagents

Blocked until Q1 and Q2 of PRD section 14.2 are closed.

- [ ] Codex subagent format confirmed
- [ ] Antigravity and OpenCode subagent paths confirmed
- [ ] Per-host transformation

## Backlog

- Hooks, pending Q3
- Plugin bundles as a distribution format
- The `.agents/` neutral namespace as an explicit destination
