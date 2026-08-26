# Roadmap

Phases are defined in [`PRD.md`](PRD.md) section 15. Each one lists its exit
criterion; a phase is not done until that criterion is met.

[`runbook.md`](runbook.md) is the executable form of this list: 63 numbered
stages, each with a mechanically verifiable exit criterion.

## P0 — Specification

- [x] Host matrix verified against the hosts themselves, every row dated
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

- [x] Domain model, with `kind` and `subagent` in the resolver signature
- [x] Typed error hierarchy, sealed root (R12.7)
- [x] `plan(observed, desired)` as a pure function
- [x] Every reconciliation state unit-tested with no filesystem, adoption
      included (R10.6)

## P2 — Hosts

- [x] Host matrix as a data file
- [x] Host detection
- [x] Visibility graph and its reporting, carried as plan annotations (§7.5)
- [x] `skill list` and `skill doctor`

## P3 — Deployment

- [x] `skill deploy` and `skill remove` as Steps
- [x] Ledger — one per machine, shared by every consumer (R11.5, R11.6)
- [x] Adoption of pre-package deployments (R10.6)
- [ ] Manifest
- [x] Idempotence and every `block` state covered by a test

## P4 — `skillwire_cli`

- [x] The `skillwire` executable with its `sw` alias
- [x] Self-hosting: this repository deploys its own skills through it

## P5 — Adoption

- [ ] `macss` consumes the `skillwire` package
- [ ] `inquiry` consumes the `skillwire` package
- [ ] `inquiry`'s `clean()` narrowed to what it actually wrote — it deletes ten
      host directories wholesale today
- [x] The three transversal skills moved out of `inquiry` into `skillwire_cli`
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
