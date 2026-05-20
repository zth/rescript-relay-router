# Root Outlet Resolution

## Decision

Codex implemented root-scoped `RouteDeclarations.<Root>.outletForUrl(url)` helpers that return the deepest matched route's effective outlet as a generated typed variant.

## Why

Kandan needs to decide whether a URL belongs in a route slot without duplicating route parsing or manually walking route configs. The router already has a matcher and generated route declarations, so this belongs in generated declarations rather than app code.

## Implementation

- Runtime route declarations now store both direct `outlet` and inherited `effectiveOutlet`.
- Codegen propagates a parent effective outlet to descendants unless a route declares its own outlet.
- `RelayRouter.Internal.outletForUrl(compiledRoutes, url)` uses the existing compiled route matcher and returns the deepest match's `effectiveOutlet`.
- `RouteDeclarations.<Root>.outletForUrl(url)` scopes matching to that root's route tree, uses a module-level precompiled route matcher, and maps the internal string outlet to the root module's `outlet` variant.
- Root modules are now emitted for every top-level route. Only routes marked `entrypoint: true` expose `make`.

## Verification

Codex verified with:

- `yarn rescript format`
- `yarn build`
- `yarn test`
- `git diff --check`

## Non-Goals

- No rendering behavior changes.
- No support for multiple simultaneous outlet branches in one URL.
- No app-specific Kandan pane or overlay API.
