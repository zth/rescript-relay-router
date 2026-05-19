# Precompiled Route Matching

## Decision

Precompile route-tree matching metadata once when a router instance is created. Keep the existing
`matchRoutes` helper as a compatibility wrapper, but have router runtime matching use
`compileRoutes` plus `matchCompiledRoutes`.

## Who

zth-linzumi asked Codex to take `opt/precompile-route-matching` through to a merge-ready PR after
the route slots and route declaration entrypoint work landed. Codex rebased the existing branch on
latest `main` and kept the implementation focused on the route-matching hot path.

## Why

The route tree is static for a router instance, but the old matching path flattened and ranked the
tree and compiled path regexes on every match. That cost is repeated for the initial location, each
history update, and every route preload triggered by links. Precompiling moves stable work to router
construction while preserving route object identity and existing match output.

## Verification

- Compiled matching tests cover parity with the compatibility `matchRoutes` path for root, nested,
  dynamic param, regex param, splat, trailing slash, and unmatched routes.
- Tests cover preserving matched route object identity.
- Tests cover preserving `matchPath` result pattern identity for callers using the vendored helper
  directly.
- Tests cover that compiled matching does not re-walk route children after compilation.

## Non-Goals

- This does not change route config syntax or generated route declarations.
- This does not add a benchmark harness beyond focused regression tests.
- This does not change basename behavior.
