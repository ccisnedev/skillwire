# Changelog

All notable changes to this project are documented in this file.

The format loosely follows [Keep a Changelog](https://keepachangelog.com/)
and the project adheres to [Semantic Versioning](https://semver.org/).

This file records delivery history at the **project** level: what changed for
the people who use the system, not every commit. Architectural decisions and
their rationale belong in `docs/adr/`.

## [Unreleased]

### Added

- Specification of the `skillwire` package in `docs/PRD.md`: host matrix,
  cross-host visibility graph, reconciliation states, ledger and manifest, CLI contract.
- `docs/architecture.md`: two layers, the materialisation/reconciliation seam,
  and how other consumer CLIs embed the library.
- ADR 0002 — deployment is by copy, not by link.
- ADR 0003 — the package is named `skillwire`.
- ADR 0004 — how the word `skillwire` is written, now that it names the package,
  the CLI and the executable.
- Skeletons for the `skillwire` package and `skillwire_cli`.

### Changed

- Replaced the scaffolded `api`, `app`, `db` and `infra` layers with the two
  this project actually has: `code/skillwire` and `code/cli`.
- Every mention of `skillwire` in the documentation now states which of the three
  things it means: the package, `skillwire_cli`, or the executable.

### Fixed
