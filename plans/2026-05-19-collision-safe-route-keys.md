# Collision-Safe Route Keys

## Decision

Generated route keys should be built through `RelayRouter.Internal.RouteKey` instead of direct string
concatenation. The key format uses length-prefixed route names, path param names and values, query
param names and values, and repeated query param arrays.

## Who

zth-linzumi asked Codex to take `fix/collision-safe-route-keys` through to a merge-ready PR after
the route matching optimization landed. Codex rebased the branch onto latest `main`, skipped the
already-merged optimization-doc commit, and adapted the fix to the newer route slots and route
declaration entrypoint codegen.

## Why

The old generated route keys concatenated param values without unambiguous field boundaries. That
could let distinct route states share one prepared cache key. The new encoder includes names,
missing-versus-empty state, value boundaries, and repeated query param values.

## Verification

- Unit tests cover adjacent path param collisions.
- Unit tests cover path and query field names.
- Unit tests cover missing versus empty query params.
- Unit tests cover repeated query param value boundaries and order.
- Codegen tests cover path params, scalar query params, array query params, and original URL param
  names when generated prop names need collision protection.

## Non-Goals

- This does not normalize repeated query param order; order remains part of the key.
- This does not change public route config syntax.
