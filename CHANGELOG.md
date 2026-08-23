# Changelog

All notable changes to this project are documented in this file.

The format loosely follows [Keep a Changelog](https://keepachangelog.com/)
and the project adheres to [Semantic Versioning](https://semver.org/).

This file records delivery history at the **project** level: what changed for
the people who use the system, not every commit. Architectural decisions and
their rationale belong in `docs/adr/`.

## [Unreleased]

### Added

- Specification of Skillwire in `docs/PRD.md`: host matrix, cross-host
  visibility graph, reconciliation states, ledger and manifest, CLI contract.
- `docs/architecture.md`: two layers, the materialisation/reconciliation seam,
  and how other consumer CLIs embed the library.
- ADR 0002 — deployment is by copy, not by link.
- ADR 0003 — the package is named `skillwire`.
- Skeletons for the `skillwire` library and the `skillwire_cli` executable.

### Changed

- Replaced the scaffolded `api`, `app`, `db` and `infra` layers with the two
  this project actually has: `skillwire` and `cli`.

### Fixed
