# rescript-relay-router

## 1.1.1

### Patch Changes

- 9f77cef: Prevent crash in LSP when getting unexpected file scheme less file.

## 1.1.0

### Minor Changes

- 94cf864: Expose any child route params to parent routes.

## 1.0.4

### Patch Changes

- cd28874: Fix peer dependencies.

## 1.0.3

### Patch Changes

- 26d29f8: Fix the type of the generated loadFn in loadRouteRenderer

## 1.0.2

### Patch Changes

- aa53f8a: Use Vite 4.x
- af032da: Use native dynamic import instead of Vite plugin hack"

## 1.0.1

### Patch Changes

- fe2a3a7: Migrate from old hand-rolled stdlib to Core.

## 1.0.0

### Major Changes

- 20f90dd: Adapt to RescriptRelay v3

### Patch Changes

- 14afbd9: Get rid of trailing units.

## 0.2.0

### Minor Changes

- 5f6cbbb: Move to ReScript v11 and make it build in uncurried mode

## 0.1.1

### Patch Changes

- b585a87: Add useMakeLinkWithPreservedPath helper to generated route cod"

## 0.1.0

### Minor Changes

- 7cb0b5a: Now using JSX v4, which means JSX v4 is required.

### Patch Changes

- 7cb0b5a: Pin (old) stdlib version for now.
- 7cb0b5a: Move to use JSX v4

## 0.0.27

### Patch Changes

- 8f055d9: Inline what we use from React Router so we do not need to depend on the entire package, plus can easily modify the matching logic to our needs.
- 8f055d9: Fix typed path params that was previously broken.

## 0.0.26

### Patch Changes

- 3d92f0a: Remove peer dep again and switch to package version of stdlib with mjs shipped.

## 0.0.25

### Patch Changes

- 504e374: LSP: Support custom request for returning what routes matches arbitrary URLs
- 6646831: Temporary peer dep to @gabnor/rescript-stdlib until real stdlib pkg is published.

## 0.0.24

### Patch Changes

- b7ff499: Migrate relevant underlying code to the new ReScript standard library (currently in private testing).
- c51701d: LSP: Code lens in ReScript files detailing how many routes the file is referenced in.
- c51701d: LSP: Support custom LSP command for returning routes for a file.

## 0.0.23

### Patch Changes

- 19855f2: Fix link generation for array params.

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
