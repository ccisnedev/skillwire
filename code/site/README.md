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

[`design_system`](https://github.com/ccisnedev/design_system) is depended on by
`path:`, not by version. It is deliberately unpublished — see that repository's
`docs/adr/0002` — so `pubspec.yaml` points at a directory:

```yaml
design_system:
  path: ../../../design_system/code/design_system
```

**It must be checked out beside `skillwire`.** That holds locally and in CI:
`pages.yml` clones both repositories as siblings under `repo/`, because
`actions/checkout` cannot write outside the workspace and the relative path has
to resolve either way.

A change in `design_system` does not touch this repository and so does not
trigger a deploy. Until the design system is published and this site depends on
a version, redeploying after a change over there is `workflow_dispatch`.
