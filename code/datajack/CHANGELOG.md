# Changelog

## 0.2.0

Migrated to `cli_router` ^0.2.0 and `modular_cli_sdk` ^0.8.0.

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

Same five routes, same validation messages, same exit codes.

### BREAKING: the `--json` error envelope on stderr has a new shape

A `--json` invocation that fails now writes a different envelope on stderr.
Anything parsing it (a script, an agent, a wrapper CLI) written against
0.1.0's shape must be updated.

Old (0.1.0, `cli_router` 0.1.0's own error rendering):

```json
{
  "error": "missing_parameter",
  "message": "--host is required and has no default (R12.2).",
  "exitCode": 64,
  "isRetryable": false
}
```

New (0.2.0, `modular_cli_sdk` 0.8.0's `CommandException.toJson`):

```json
{
  "error": {
    "id": "missing-parameter",
    "message": "--host is required and has no default (R12.2).",
    "exitCode": 64
  }
}
```

What changed:

- `error` is no longer the machine-readable identifier itself; it is now an
  object, and the identifier moved to `error.id`.
- The identifier is now kebab-case (`missing-parameter`, `unknown-host`)
  rather than snake_case (`missing_parameter`, `unknown_host`).
- `message` and `exitCode` moved from the envelope's top level to inside
  `error`, alongside `id`.
- `isRetryable` is gone. The SDK does not carry that field; nothing in this
  package ever set it to anything other than `false`, so nothing here relied
  on it being `true`.

A consumer that used to read `decoded['error']` as a string now reads
`decoded['error']['id']`; `decoded['message']`/`decoded['exitCode']` move to
`decoded['error']['message']`/`decoded['error']['exitCode']`.

## 0.1.0

First release. The `skill` module — five routes over the `skillwire` package —
extracted from `skillwire_cli` so that `macss` and `inquiry` mount the same one
rather than each carrying a copy.

`consumer` is a parameter rather than a constant, which is the whole point: one
module serves three CLIs, and each writes its own name into the ledger rows it
creates. That is what makes "deployed by a different consumer" answerable on a
machine several of them share.
