# Route Declaration Entrypoints Plan

Date: 2026-05-19

## Decision

Add `entrypoint: true` for top-level routes.

Marked routes get a generated `RouteDeclarations.<RouteName>.make()` module that returns only that
top-level route tree. The existing `RouteDeclarations.make()` continues to return every top-level
route tree.

Do not allow `RelayRouter` as an entrypoint route name. That generated module would shadow the
router runtime module in `RouteDeclarations`.

## Who

zth-linzumi asked Codex to take the old `task/separately-renderable-roots` work through to a PR
after typed route slots landed. Codex renamed the config field from `separatelyRenderable` to
`entrypoint` while rebasing the implementation onto latest `main`.
Codex also reserved `RelayRouter` for entrypoint routes after PR review identified the generated
module shadowing risk.

## Why

Typed route slots cover outlet placement inside a matched route tree. Entrypoints cover a separate
need: constructing a router that matches, prepares, preloads, and renders only one top-level route
tree for multi-entry apps, embedded apps, admin surfaces, or isolated route roots.

## Verification

- Parser tests cover valid top-level `entrypoint: true`, nested `entrypoint`, and non-boolean
  `entrypoint` values.
- Parser tests cover rejecting the `RelayRouter` entrypoint route name.
- Codegen tests cover generated standalone `RouteDeclarations.<RouteName>.make()` modules and
  preservation of the all-routes `RouteDeclarations.make()`.
- Ran `yarn workspaces foreach run rescript format -all`.
- Ran `yarn build`.
- Ran `yarn test`.
- Ran `yarn install --immutable`.
- Ran `yarn changeset status --since origin/main`.
- Ran `git diff --check`.

## Non-Goals

- This does not change route-slot behavior.
- This does not make nested routes independently renderable.
- This does not remove or narrow the existing all-routes `RouteDeclarations.make()` entrypoint.
