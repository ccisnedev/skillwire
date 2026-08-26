# Roadmap

Phases are defined in [`PRD.md`](PRD.md) section 15. Each one lists its exit
criterion; a phase is not done until that criterion is met.

## P0 — Specification

- [x] Host matrix verified against the hosts themselves
- [x] Cross-host visibility graph
- [x] Deployment mechanism decided and recorded (ADR 0002)
- [x] Reconciliation states enumerated
- [x] Ledger and manifest split defined
- [x] CLI contract defined
- [x] Name decided and recorded (ADR 0003)
- [x] How the name is written decided and recorded (ADR 0004)
- [ ] Reviewed

## P1 — Domain and reconciliation

- [ ] Domain model, with `kind` and `subagent` in the resolver signature
- [ ] `plan(observed, desired)` as a pure function
- [ ] Every reconciliation state unit-tested with no filesystem

## P2 — Hosts

- [ ] Host matrix as a data file
- [ ] Host detection
- [ ] Visibility graph and its reporting
- [ ] `skill list` and `skill doctor`

## P3 — Deployment

- [ ] `skill deploy` and `skill remove` as Steps
- [ ] Ledger
- [ ] Manifest
- [ ] Idempotence and every `block` state covered by a test

## P4 — `skillwire_cli`

- [ ] The `skillwire` executable with its `sw` alias
- [ ] Self-hosting: this repository deploys its own skills through it

## P5 — Adoption

- [ ] `macss` consumes the `skillwire` package
- [ ] `inquiry` consumes the `skillwire` package
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
