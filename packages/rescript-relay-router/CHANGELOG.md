# rescript-relay-router

## 0.0.22

### Patch Changes

- 9529b95: Restructure internal types in route codegen so that inference for query params etc works reliably again.

## 0.0.21

### Patch Changes

- a12579e: Fix issue with setting array query params.
- a12579e: Support running route loaders on change of query parameters as well, not just on path changes. Introduce shallow routing mode to preserve previous behavior of `setParams` not triggering route data loaders.
- f396f8e: Add `makeLinkFromQueryParams` helper to route codegen. This helper is intended to be flexible and versatile, enabling a few quality-of-life patterns for producing links in more exotic scenarios.
- a12579e: Expose imperative `getActiveSubRoute` in addition to `useActiveSubRoute`. This makes it easy to imperatively figure out what sub route is active, without having to be in React land.
- 65523d8: Update to Vite 3
- a12579e: Add support for typed path parameters, letting you type path parameters as polyvariants in the cases when all values a path parameter can have is known statically.

## 0.0.20

### Patch Changes

- 55c5764: Fixed rescript-relay-router command not being executable
- c42d505: ReScript Relay Router now supports Windows for development
- c42d505: Upgrade rescript-relay to 1.0.0-rc2 and use react-relay and relay-runtime 14
