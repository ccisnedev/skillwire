# `skillwire_site`

[skillwire.ccisne.dev](https://skillwire.ccisne.dev), as source rather than as
output. A [Jaspr](https://jaspr.site) app: the pages are Dart components and the
CSS is generated from typed Dart, so a colour or a spacing step cannot be
mistyped into something that silently does nothing.

Every visual decision lives in one of two places — the section that owns it, or
the design system. There is nothing hand-written under `build/`.

## It ships no JavaScript

No component here is annotated `@client`, so the built `index.html` contains no
`<script>` tag at all. That is a property to preserve, not a coincidence: adding
one `@client` component changes the page from a document into an application.

## Building

```bash
dart pub global activate jaspr_cli
jaspr serve                          # http://localhost:8080
jaspr build                          # → build/jaspr/
```

`build/jaspr/packages/` is emitted by `build_web_compilers` and referenced by
nothing, since there is no client entrypoint. Only `index.html` and
`favicon.ico` need to be deployed.

## The design system is a sibling checkout

`design_system` is depended on by `path:`. It is unpublished and deliberately
so — see that repository's `docs/adr/0002`. Two consequences:

- `design_system` must be checked out beside `skillwire`.
- **This site cannot be built in CI yet.** A GitHub Actions runner checks out
  one repository and will not have the sibling. Publishing waits until the
  design system is named and public; until then the build is local.
