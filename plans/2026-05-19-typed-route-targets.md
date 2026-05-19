# Typed Route Targets

## Decision

Codex implemented generated typed route targets for each generated route module and each route subtree.

Each generated route file now exposes:

- `type target`
- `targetFromMatchedRoute`
- `targetFromLocation`
- `targetToPath`
- `targetKey`
- `targetRouteName`
- `module Target`

The nested `Target.t` variant represents the deepest active route in that subtree, with path params and query params decoded into the generated target record.

## Why

Kandan needs to turn the currently matched ShellV2 route into pane state without manually trying every generated `parseRoute` helper in app code. The router already has the matched route stack during navigation, so the generated API should expose that matched identity and decoded params directly.

This keeps generated route helpers as the source of truth for route names, path params, query params, target serialization, and route keys.

## Implementation Notes

- `currentRouterEntry` now carries `queryParams` and a `matchedRoutes` snapshot.
- `matchedRoute` stores route name, prepared route key, path params, slot names, and outlet.
- `RelayRouter__MatchedRoutes.make` builds the snapshot from the router match stack and prepared matches.
- Generated `Target.fromEntry` uses the entry snapshot and does not reparse routes.
- Generated `Target.useCurrent` uses the current route entry plus the live location query string so shallow query navigations can update target query params.
- Generated `Target.fromLocation` remains available for non-hook utility code, but the preferred runtime path is `fromEntry`/`useCurrent`.
- Slots and outlets are metadata on the matched route; they do not change target identity. The target identity remains the leaf route inside the selected route subtree.

## Verification

Codex verified with:

- `yarn rescript format`
- `yarn build`
- `yarn test`
- `git diff --check`

Added coverage:

- package codegen tests for target module generation and `Routes.res` alias-only behavior
- package unit tests for matched route snapshot construction
- client-rendering tests for `Target.fromEntry`, `Target.fromLocation`, `Target.toPath`, `Target.key`, and `Target.routeName`

## Non-Goals

- No route metadata helpers such as `surface`, `kind`, or `isPaneTarget` yet.
- No explicit multi-target URL model beyond the current route slot work.
- No Kandan-specific pane or overlay API.
