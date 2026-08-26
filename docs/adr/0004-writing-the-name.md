# ADR 0004: How the word `skillwire` is written

**Status:** Accepted

**Relates to:** ADR 0003, which chose the name.

## Context

ADR 0003 named the package `skillwire`. The word now denotes three separate
things, and the documentation used all three interchangeably:

| The word appeared as | Meaning | Example before this ADR |
|---|---|---|
| `skillwire` | the Dart library package | `code/skillwire/pubspec.yaml` |
| `skillwire` | the executable | `executables: skillwire: main` |
| `skillwire` | the canonical CLI | `architecture.md`: "The canonical `skillwire` CLI" |
| Skillwire | the project as a whole | `PRD.md`: "Skillwire is the layer that…" |
| *skillwire* | Shadowrun's cyberware | ADR 0003 |

The collisions were not cosmetic. Two of them changed meaning:

- The architecture diagram carried two nodes labelled `skillwire`: one inside
  *Consumer CLIs*, one as the library they depend on. The diagram drew a
  dependency from a name to itself.
- Non-negotiable rule 1 read *"Never destroy what Skillwire did not deploy"*,
  while `architecture.md` requires that a deployment overwriting **another
  consumer's** artifact be planned as `block`. Read literally, rule 1 permitted
  destroying a `macss` deployment, because the `skillwire` package did deploy it.
  The rule was written about the wrong actor.

Renaming was considered and rejected: `skillwire` as the package and
`skillwire_cli` as the CLI is the pub.dev idiom, and an executable that does not
carry the product name is worse for the user than a word that needs a qualifier.

## Decision

**The three identifiers stay as they are. Prose carries the qualifier.**

| Written as | Denotes | Never written as |
|---|---|---|
| the `skillwire` package | the Dart library | a bare `skillwire` |
| `skillwire_cli` | the Dart package of the canonical CLI | "the skillwire CLI" |
| the `skillwire` executable | the command, aliased `sw` | a bare `skillwire` |
| Skillwire | the project: repository, docs, product | the subject of a requirement |
| *skillwire*, italic | Shadowrun's cyberware | outside ADR 0003 and "On the name" |

Two rules follow:

1. **Every mention in prose carries its qualifier.** A bare `skillwire` in a
   sentence is non-conforming. In code, identifiers stay bare: `name: skillwire`
   in a pubspec, `import 'package:skillwire/…'`, `skillwire --help`.
2. **Skillwire the project never acts.** Requirements name the `skillwire`
   package, `skillwire_cli`, or the consumer. Where a rule is about ownership,
   the actor is **the acting consumer**, because the ledger records ownership
   per consumer and `macss` and `inquiry` are consumers too.

Normative form: **R12.0** in `docs/PRD.md` §12.1.

## Consequences

**Rule 1 changes meaning, correctly.** It now reads *"Never destroy what the
acting consumer did not deploy"* in `README.md`, `PRD.md` §16 and G3. This is
what the ledger already implements; the old wording contradicted it.

**Sentences get longer.** "The `skillwire` package MUST NOT define a plan type
of its own" is heavier than "Skillwire MUST NOT". Accepted: a specification is
read by people deciding what to build, and an ambiguous actor in a MUST is a
defect, not a style choice.

**Reviewable by grep.** A bare `skillwire` in prose is mechanically detectable,
so conformance does not depend on a reviewer noticing.

**Extends to future names.** If the marketplace of issue #1 is built, whatever
it is called enters this table before it enters the prose.
