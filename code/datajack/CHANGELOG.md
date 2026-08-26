# Changelog

## 0.1.0

First release. The `skill` module — five routes over the `skillwire` package —
extracted from `skillwire_cli` so that `macss` and `inquiry` mount the same one
rather than each carrying a copy.

`consumer` is a parameter rather than a constant, which is the whole point: one
module serves three CLIs, and each writes its own name into the ledger rows it
creates. That is what makes "deployed by a different consumer" answerable on a
machine several of them share.
