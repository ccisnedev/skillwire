# Changelog

## 0.2.0

Migrated to `cli_router` ^0.2.0 and `modular_cli_sdk` ^0.7.0.

- Every `CliParam.string`/`.boolean` declaration now uses the SDK's
  type-specific factories (`CliParam.string`, `.enumeration`, `.flag`) with
  their newly required named parameters (`abbr`, `required`, `repeatable`,
  `defaultValue`).
- `--scope` is now declared as `CliParam.enumeration`, since the old
  `allowed:` parameter on `CliParam.string` no longer exists.
- Every `Input`'s `schemaFields`/`params` static field is gone: a route's
  contract is declared once, as `CliContract`, at its `skill_builder.dart`
  registration call (`contract:`), which the SDK now requires explicitly,
  alongside the also-now-required `globals: true`.
- `CommandException(code: ...)` is now `CommandException(id: ...)`, and every
  id is kebab-case, as the SDK now requires. `skillwire`'s own
  `SkillwireError.code` stays snake_case (its documented, stable contract);
  the dash swap happens only at the `datajack/lib/src/errors.dart` boundary.

No behavioral change: the same five routes, the same validation messages, the
same exit codes.

## 0.1.0

First release. The `skill` module — five routes over the `skillwire` package —
extracted from `skillwire_cli` so that `macss` and `inquiry` mount the same one
rather than each carrying a copy.

`consumer` is a parameter rather than a constant, which is the whole point: one
module serves three CLIs, and each writes its own name into the ledger rows it
creates. That is what makes "deployed by a different consumer" answerable on a
machine several of them share.
