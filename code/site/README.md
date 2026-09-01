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

## The design system is a pinned commit

[`design_system`](https://github.com/ccisnedev/design_system) is a git
dependency, pinned to a commit:

```yaml
design_system:
  git:
    url: https://github.com/ccisnedev/design_system
    path: code/design_system
    ref: <commit>
```

Not a path, and not a version. A relative path needed the two repositories
checked out as siblings, which a runner does not do on its own — every workflow
that built this site had to clone the other repository into a contrived layout
first. And there is no version to depend on: `publish_to: none` over there is
deliberate, so a commit is what there is to name.

**The pin is the useful part.** A change over there does not reach this site
until that `ref` moves, and moving it is a commit here — which triggers the
deploy like any other change. Unpinned, the published page and its source would
drift apart with nothing saying so.

To iterate on both at once, add a `pubspec_overrides.yaml` (git-ignored):

```yaml
dependency_overrides:
  design_system:
    path: ../../../design_system/code/design_system
```
