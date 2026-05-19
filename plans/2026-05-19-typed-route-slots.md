# Typed Route Slots Plan

Date: 2026-05-19

## Decision

Add first-class typed route slots to `RescriptRelayRouter`.

Routes can declare named slots, and descendant routes can target one of those slots with `outlet`.
The URL remains a normal route URL. A route that targets an outlet is still matched, prepared,
preloaded, and rendered like any other route, but its matched branch is rendered into the nearest
ancestor route that declares the named slot.

## Who

zth-linzumi requested the feature for Kandan's multi-pane settings/preferences overlay route model.
Codex made the implementation decision after comparing Angular named outlets, Next parallel routes,
and TanStack route masking.

## Why

Kandan wants routes such as `/preferences/account?paneConfig=pcfg_123` to be normal foreground
routes while rendering over a pane grid restored from `paneConfig`. Encoding both the pane route and
overlay route in a single path would make the URL misleading. Typed slots preserve normal routes
and keep placement declarative.

## Implementation Tranche

- Parse `slots: [{"name": "Overlay"}]` on route entries.
- Parse `outlet: "Overlay"` on descendant route entries.
- Validate slot and outlet names.
- Generate typed slot components such as `<Routes.ShellV2.Slots.Overlay />`.
- Carry slot/outlet metadata into runtime route declarations.
- Split a matched branch at the nearest slot host and render the outlet branch through slot context.
- Keep the slot render/split path free of local `ref` cells; route nesting uses a reducer and outlet
  discovery uses recursive helpers.
- Add a small client-rendering sample route so generated slot APIs are visible in normal example
  output.
- Keep generated route declaration output free of trailing whitespace when empty lines are indented.
- Keep `Routes.res` as an alias-only index. Generated slot component implementations live in the
  generated route module, while `Routes.res` aliases them with `module Slots = Route__..._route.Slots`.
- Cover the runtime slot split directly in tests: outlet branches are removed from primary
  `childRoutes`, keyed to the nearest ancestor slot host, and retained in `allMatches` for lifecycle
  handling.
- Preserve the historical `currentRouterEntry.preparedMatches` field as an alias of all prepared
  matches, while adding `primaryMatches` for render placement and `slotContents` for slots.
- Tighten generated route whitespace while touching codegen: generated route files should not emit
  trailing whitespace, whitespace-only lines, missing final newlines, or empty-section separator gaps.

## Verification

- Added parser tests for valid slots/outlets and invalid outlet references.
- Added codegen tests for generated slot components and route metadata.
- Ran `yarn workspace rescript-relay-router build`.
- Ran `yarn workspace rescript-relay-router test -- RescriptRelayRouterCli`.
- Ran `yarn workspace rescript-relay-router test`.
- Added `RouteSlots.test.res` for the runtime split behavior; the router suite now runs 25 tests.
- Added slot-provider rendering coverage for `<RelayRouter.Slot />`.
- Ran `yarn workspace @rescript-relay-router-example/client-rendering router:generate`.
- Ran `yarn workspace @rescript-relay-router-example/client-rendering build:rescript`.
- Ran `yarn workspace @rescript-relay-router-example/client-rendering test`.
- Ran `yarn workspace @rescript-relay-router-example/express router:generate`.
- Ran `yarn workspace @rescript-relay-router-example/express build:rescript`.
- Ran `git diff --check`.
- Scanned generated route files with `rg -n '[ \t]+$' examples/*/src/routes/__generated__`.
- Tried `yarn build`; it reached the client-rendering example after successfully building the
  package and test utils, then failed in `rescript-relay-compiler` because Watchman timed out while
  waiting for its cookie file. This appears unrelated to the route-slot changes.

## Known Blockers Or Non-Goals

- This tranche does not add special close/back helpers.
- This tranche does not encode multiple independent route branches in the URL.
- This tranche supports one outlet branch per matched route path. Multiple simultaneously active
  slots can be added later with an explicit URL/state model.
- The example ReScript builds still emit the pre-existing `Stdlib.Exn.t` deprecation warning from
  `examples/*/src/utils/NetworkUtils.res`; this tranche did not change that warning.

## Future Design: Explicit URL Slot Targets

Decision: defer explicit URL-backed multi-slot targets for now.

Who: zth-linzumi chose to skip this for the current tranche after discussing the URL model with
Codex.

Why: the current Kandan settings/preferences overlay use case only needs one outlet branch in the
matched route path. Supporting multiple simultaneously active independent slots needs an explicit
URL representation and a larger router design.

Preferred future URL shape:

```text
/w/default/c/general?paneConfig=pcfg_123&slot.Overlay=%2Fpreferences%2Faccount&slot.Inspector=%2Fusers%2F123
```

Semantics:

- The path before query params is the primary route branch.
- Query params with the `slot.` prefix are router-owned slot targets.
- Each `slot.<SlotName>` value is an encoded route target URL.
- The router matches, prepares, and renders the primary branch plus each slot target branch.
- Router-owned `slot.*` params should not be passed to app route query param decoders.
- Closing a slot is ordinary URL state management: remove that slot query param while preserving
  the rest of the URL.

Likely implementation phases:

1. Generate typed `Route.target(...)` values for routes.
2. Parse and match `slot.<SlotName>=<encoded-target>` query params.
3. Prepare all active branches and provide each slot branch to the existing generated slot
   components.
4. Add ergonomic generated helpers for setting and clearing slot params.

Non-goal for this tranche: supporting two independent active branches such as `slot.Overlay` and
`slot.Inspector` at the same time. The implemented model only splits the normal matched branch once,
at the first descendant route with `outlet`.
