# Skills shipped by this CLI

A skill belongs to the release of the CLI that transports it, so it ships here
rather than in a shared location. Every consumer CLI holds its own skills under
its own `assets/skills/modules/`.

## Layout

```
modules/
  core/        transversal — used in any context, deployed almost always
  <domain>/    topical — deployed only where relevant
```

Modules group by **generality**, not by topic. A skill usable across domains
belongs in `core`. That is what makes "what do I deploy here?" answerable:
`core`, plus the domains in play.

## Rules

- The directory name is the artifact name, and it must equal the `name` field in
  the frontmatter.
- Names must be globally unique across every module and every consumer CLI.
  Modules organise the source tree; deployment is flat.
- Version and provenance go in the `metadata` map of the `SKILL.md` frontmatter.
  There is no `skill.yaml`.
- `CHANGELOG.md` per skill is permitted.
