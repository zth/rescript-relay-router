# Router Optimization Opportunities

This document captures a holistic pass over `rescript-relay-router` with a focus on runtime performance, bundle shape, code splitting, and maintainability of the hot paths.

The intent is that each section can be picked up as an independent work item. Some items are direct optimizations with low semantic risk. Others are architectural directions that should start with measurement or a narrow proof of concept.

## Priority Overview

| Priority | Area | Expected impact | Risk | Suggested owner |
| --- | --- | --- | --- | --- |
| P1 | Reuse unchanged prepared matches with explicit freshness policy | High for nested routes with parent queries | High | Relay/runtime |
| P1 | Centralize location subscriptions | Medium to high in nav-heavy UIs | Medium | React runtime |
| P2 | Split route declaration payload from route prepare modules | High in very large apps | High | Codegen/build |
| P2 | Verify and improve renderer chunk boundaries | Medium bundle-size opportunity | Medium | Codegen/build |
| P2 | Pool link intersection observers | Medium on pages with many links | Low | Link/runtime |
| P2 | Replace reflective disposable extraction | Medium runtime + API robustness | Medium | Relay/runtime API |
| P3 | Reduce repeated query decoding | Medium in query-heavy route trees | Medium | Codegen/runtime |

Completed since this note was drafted:

- Precompiled route matching landed in #195. The router now compiles route metadata once per router
  instance and reuses it for initial matching, navigation, and link preloading.
- Route declaration entrypoints landed in #199 as `entrypoint: true` on top-level routes. The
  generated API is `RouteDeclarations.<RouteName>.make()`, with `RouteDeclarations.make()` still
  returning all top-level route trees.
- Collision-safe route keys landed in #194. Generated route keys now use a length-prefixed internal
  encoder that includes field names, missing-versus-empty query param state, and repeated query
  param values.

## Measurement Baseline

Before changing behavior, add a repeatable way to measure the current costs:

- Build a synthetic route tree with tens, hundreds, and thousands of routes.
- Include nested routes, static routes, dynamic params, regex path params, splats if supported, and query-param-heavy routes.
- Render pages with many `RelayRouter.Link` instances using `OnInView`, `OnIntent`, and `OnRender`.
- Measure client navigation time from history event to first render attempt.
- Measure number of `prepare` calls per navigation.
- Measure number of history listeners on a page with many active route hooks.
- Measure client bundle size and chunk graph for a realistic app.

Suggested test fixtures:

- Extend `packages/rescript-relay-router/test/RouterUtils.test.res` for pure route matching and route-key behavior.
- Add focused tests around generated output in `packages/rescript-relay-router/test/RescriptRelayRouterCli.test.res`.
- Add a larger example or benchmark fixture under `examples/` only if it exercises realistic route trees and Vite chunk output.

Use this baseline to prevent a common failure mode: making the router theoretically cleaner while moving cost from one phase to another without observing the final app behavior.

## 1. Precompile Route Matching

### Landed Shape

This landed in #195. The vendored React Router helper now exposes a compiled matching path:

```rescript
type compiledRoutes

external compileRoutes: array<route> => compiledRoutes = "compileRoutes"

external matchCompiledRoutes: (
  compiledRoutes,
  RelayRouter__History.location,
) => option<array<routeMatch>> = "matchCompiledRoutes"
```

The JS side splits matching into two phases:

- `compileRoutes(routes)`:
  - flatten routes once
  - rank branches once
  - precompute route metadata
  - optionally precompile path regexes for route segments
- `matchCompiledRoutes(compiledRoutes, location)`:
  - decode pathname
  - iterate ranked branches
  - match against precomputed branch metadata

`matchRoutes` remains as a compatibility wrapper. `Router.make` compiles route metadata once and
uses the compiled matcher for initial matching, history updates, and route preloading.

### Validation

- Existing router tests pass.
- Route-matching parity tests cover root, nested, dynamic param, regex param, splat, trailing slash,
  and unmatched routes.
- Tests cover preserving route object identity.
- Tests cover that compiled matching does not re-walk route children after compilation.
- Vite build still tree-shakes the vendored helper as before.

### Risks

- Future vendored React Router changes still need parity tests because this helper is modified.

## 2. Reuse Unchanged Prepared Matches With an Explicit Freshness Policy

### Current State

On navigation, all matched routes are prepared again:

- `packages/rescript-relay-router/src/RelayRouter.res`
- `packages/rescript-relay-router/src/RelayRouter__Internal__DeclarationsSupport.res`

This is intentional. The current code comments explain that Relay invalidation/staleness requires rerunning `Query.load` so Relay can decide whether to refetch.

The downside is that a child-only navigation can still rerun parent route preparation. In nested layouts, parent routes often hold expensive layout queries or broad fragments. Repreparing every matched route can increase network pressure and cause unnecessary disposable churn.

### Opportunity

Add a route-level policy that controls when an existing prepared entry can be reused for `Render`.

Possible API directions:

```rescript
type prepareFreshness =
  | Always
  | WhenRouteKeyChanges
  | Custom((~previous: preparedRoute, ~next: prepareProps) => bool)
```

or a simpler generated/default field:

```rescript
type route = {
  ...
  preparePolicy: preparePolicy,
}
```

Defaulting this is the important design decision:

- Keep current behavior as the default for backward compatibility.
- Allow routes to opt into reuse when the app author knows the route prepare is stable.
- Potentially generate a conservative policy for routes with no query/data preparation.

### Implementation Steps

1. Add a policy field to `RelayRouter__Types.route`.
2. Update codegen to emit the default policy for each route.
3. Extend `prepareRoute` in `DeclarationsSupport` to decide whether `Render` can reuse an existing prepared route.
4. Ensure reused prepared entries clear any preload cleanup timeout when they become active.
5. Ensure route unmount disposal behavior still runs exactly once.
6. Add route renderer API support if the policy should be user-configurable in `makeRenderer`.
7. Add tests:
   - unchanged parent route is reused when opted in
   - changed route key still prepares
   - default behavior remains current behavior
   - stale preload cleanup is canceled when reused for render

### Validation

- Parent route `prepare` call count drops on child-only navigations when opted in.
- Relay invalidation behavior remains intact for routes using the default policy.
- Query disposables are not disposed before render.
- Existing app behavior does not change unless the route opts in.

### Risks

- Incorrect reuse can serve stale Relay preloaded query refs.
- The policy needs clear docs. Users should understand when reuse is safe.
- A custom policy can become an API surface that is hard to evolve.

## 3. Split the Route Declaration Payload From Lazy Route Prepare Modules

### Current State

Route renderers are dynamically imported. However, `RouteDeclarations.make()` eagerly creates the complete runtime route object tree. The generated declarations include per-route closures for:

- route renderer loading
- `makePrepareProps`
- `makeRouteKey`
- `preloadCode`
- `prepare`
- children

Relevant generator code:

- `packages/rescript-relay-router/cli/RescriptRelayRouterCli__Codegen.res`

This keeps route renderers out of the initial bundle, but not necessarily all route metadata and typed prepare-prop code.

### Opportunity

Split the generated route output into:

1. A small always-loaded match manifest:
   - route path
   - route name
   - children
2. Lazy per-route modules:
   - prepare prop decoding
   - route key building
   - route renderer import
   - route-specific query param parsing if not needed globally

The runtime matcher only needs the match manifest. The router only needs the lazy module for matched routes that are being preloaded or rendered.

### Implementation Steps

1. Define a smaller route matching type, separate from the executable `route` type.
2. Update the matcher binding to operate on this smaller type if needed.
3. Generate a match-only `RouteDeclarations.makeRouteTree()`.
4. Generate per-route loader modules that can produce the executable route behavior when matched.
5. Update `Router.make` to accept either:
   - current eager route objects
   - new compiled/lazy route manifest
6. Start behind a new experimental API to avoid forcing migration.
7. Verify Vite chunk output. The whole purpose is defeated if the lazy modules are still pulled into the entry chunk.

### Validation

- Initial client bundle shrinks for a large generated route tree.
- Route matching still works without loading unmatched route prepare modules.
- Preloading a link loads only the modules for the matched branch.
- The server can still construct the match tree without browser APIs.

### Risks

- This is a larger architectural shift.
- It may complicate type-safe generated route module access.
- Dynamic import boundaries from generated code need careful Vite/Rollup testing.

## 4. Verify and Improve Renderer Chunk Boundaries

### Current State

Generated route renderer imports look like:

```rescript
import(Root__Todos__Single_route_renderer.renderer)
```

Scaffolded route renderer files often call through the generated `Routes` barrel:

```rescript
let renderer = Routes.Root.Todos.Single.Route.makeRenderer(...)
```

The generated route declaration code already knows the concrete module names. The route renderer chunk may not need to import the full `Routes` module.

### Opportunity

Verify whether using `Routes.Root...` inside each route renderer pulls more generated code into route chunks than necessary. If it does, change scaffolding to import/call the concrete generated route module directly:

```rescript
let renderer = Route__Root__Todos__Single_route.makeRenderer(...)
```

This may produce cleaner and smaller async chunks.

### Implementation Steps

1. Build the client example with the current scaffold style.
2. Inspect Vite output or use a bundle visualizer.
3. Change one route renderer manually to call its concrete route module.
4. Rebuild and compare chunk contents.
5. If the result is better, update `scaffold-route-renderers` generation in `RescriptRelayRouterCli__Commands.res`.
6. Consider whether existing generated examples should be updated.

### Validation

- Route renderer chunks include only the route module they need.
- No user-facing route API breaks.
- Existing hand-written renderers using `Routes` still work.

### Risks

- ReScript or Vite may already tree-shake this well enough, making the change unnecessary.
- The `Routes` access path is more ergonomic. Direct module references are less discoverable.

## 5. Centralize Location Subscriptions

### Current State

`RelayRouter.Utils.useLocation` creates a new history listener for every hook consumer:

- `packages/rescript-relay-router/src/RelayRouter__Utils.res`

Generated hooks use this helper:

- `useIsRouteActive`
- `usePathParams`
- `useQueryParams`

Navigation bars and sidebars often render many active route checks. This can create many subscriptions to the same history source and many independent state updates per navigation.

### Opportunity

Make the router expose one external-store style subscription for location. All location-consuming hooks should read from the same store.

Good implementation options:

- Store current location in router context and update it from the existing history listener in `Router.make`.
- Expose `useLocation` via `React.useSyncExternalStore` if available in the ReScript React bindings.
- Reuse the existing `router.subscribe` if the route entry location is enough.

The key goal is one history listener per router instance, not one per hook.

### Implementation Steps

1. Extend router context with:
   - `getLocation: unit => location`
   - `subscribeToLocation: (location => unit) => unsubFn`
2. In `Router.make`, update location subscribers from the existing history listener.
3. Rewrite `RelayRouter__Utils.useLocation` to subscribe to the router location store.
4. Ensure shallow navigation semantics are correct:
   - shallow query param changes may skip route preparation
   - location consumers should probably still see location changes
5. Add tests or a small instrumented fixture that verifies multiple hooks only create one history listener.

### Validation

- `useLocation` updates on push, replace, and pop.
- Generated hooks still update correctly.
- Shallow query param updates update `useQueryParams`.
- Route renderer updates still happen through the existing route-entry subscription.

### Risks

- Current router route-entry updates skip shallow navigations. Location subscribers must not accidentally inherit that behavior if query param hooks should update.
- React transition behavior should be reviewed. Some location updates may want transition scheduling, others may not.

## 6. Make Route Keys Collision-Safe

### Landed Shape

This landed in #194. Generated route keys now use `RelayRouter.Internal.RouteKey`:

```rescript
RelayRouter.Internal.RouteKey.make("Root__Todos__Single")
->RelayRouter.Internal.RouteKey.addPathParam(~name="todoId", ~value)
->RelayRouter.Internal.RouteKey.addQueryParam(~name="showMore", ~value)
```

The encoder uses length-prefixed segments for route names, field names, scalar values, and repeated
query param arrays. It distinguishes:

- adjacent string boundaries
- path and query field names
- missing query params from present empty values
- repeated query param value boundaries
- repeated query param order

### Validation

- Distinct route param sets produce distinct keys.
- Repeated query param ordering is preserved as part of the key.
- Existing preloading cache still works.

### Risks

- If current accidental collisions masked bugs, this can expose them.

## 7. Route Declaration Entrypoints

### Use Case

Some applications have multiple top-level route trees in one route definition file:

```json
[
  {
    "path": "/",
    "name": "Root",
    "children": []
  },
  {
    "path": "/admin",
    "name": "Admin",
    "children": []
  },
  {
    "path": "/embedded",
    "name": "Embedded",
    "children": []
  }
]
```

The desired behavior is to load and render only one of those root-level trees in a particular surface. For example:

- The main app shell renders only `Root`.
- An admin entrypoint renders only `Admin`.
- An embedded widget or iframe renders only `Embedded`.
- A host page may mount a separate route renderer for one named tree without pulling in the others.

This is related to code splitting, but it is a distinct requirement. The goal is not only to code split route renderers after matching. The goal is to make the top-level route tree itself a selectable render and build boundary.

### Landed Shape

This landed in #199 as route declaration entrypoints. Top-level routes can opt into a generated
standalone declaration module with `entrypoint: true`:

```json
{
  "path": "/admin",
  "name": "Admin",
  "entrypoint": true,
  "children": []
}
```

The generated route declaration construction API is:

```rescript
let routes = RouteDeclarations.Admin.make()
```

`RouteDeclarations.make()` remains the backwards-compatible all-routes API.

Route rendering remains context-driven:

```rescript
let (_, routerContext) = RelayRouter.Router.make(
  ~routes=RouteDeclarations.Admin.make(),
  ...
)

<RelayRouter.Provider value=routerContext>
  <RelayRouter.RouteRenderer />
</RelayRouter.Provider>
```

This is preferable to render-time filtering because it scopes matching, preloading, preparation, and
rendering consistently. A `RouteRenderer(~root=...)` prop would filter too late.

### Code Splitting Follow-Up

The first implementation can still generate all root-tree modules into one `RouteDeclarations.res` file. That gives the ergonomic API and runtime scoping, but it may not fully isolate bundle output.

For stronger bundle isolation, follow up by generating one declaration file per top-level route tree:

```text
RouteDeclarations.res
RouteDeclarations__Root.res
RouteDeclarations__Admin.res
RouteDeclarations__Embedded.res
```

Then `RouteDeclarations.Admin.make()` can be a small forwarding module, or app entrypoints can import `RouteDeclarations__Admin` directly. This should be validated with Vite output before committing to the split.

### Interaction With Links and Preloading

When a router is created with only one root tree:

- `router.preload` should only match that root tree.
- `RelayRouter.Link` should only preload routes in that root tree.
- Navigating to a URL outside that root tree should produce no matches.
- Type-safe `makeLink` helpers can still generate links to routes outside the current root tree if they are imported directly. That is acceptable, but docs should explain that a scoped router will not render unmatched trees.

This behavior is preferable to render-time filtering because it scopes matching, preloading, preparation, and rendering consistently.

### Validation

- `RouteDeclarations.make()` preserves current behavior and returns all top-level route trees.
- `RouteDeclarations.Admin.make()` returns only the `Admin` top-level route tree.
- Matching `/admin/...` works in an admin-scoped router.
- Matching `/embedded/...` does not work in an admin-scoped router.
- Link preloading in an admin-scoped router does not prepare root or embedded routes.
- A client entrypoint importing only the admin route declaration can be verified for bundle isolation if per-root generated files are implemented.

### Risks

- Top-level route names must be unique. They likely already are through full route names, but codegen should produce a clear diagnostic if a selectable root name would collide.
- If multiple root trees intentionally share paths, root scoping changes which one can match. That is the point of the feature, but it should be documented.
- Generating per-root files can complicate the current generated module structure and LSP helpers.
- If top-level modules share `loadedRouteRenderers`, code loading can be shared across contexts. If they do not, duplicate dynamic import state may be tracked. Decide explicitly.

## 8. Pool Link Intersection Observers

### Current State

Each `RelayRouter.Link` with `OnInView` creates its own `IntersectionObserver`:

- `packages/rescript-relay-router/src/RelayRouter__Link.res`

This is simple and works, but pages with many links can create many observers with identical options.

The current observer uses:

```rescript
threshold: 1.
```

That means the link must be fully visible before in-view preloading fires.

### Opportunity

Use a shared observer per root/options combination. Track callbacks per element.

Also consider changing the default visibility semantics:

- `threshold: 0.` or a small threshold starts preloading earlier.
- `rootMargin: "200px"` starts loading before the link enters the viewport.

The default should be conservative, but the current threshold may be too late to help for many scrolling interactions.

### Implementation Steps

1. Add root margin support to the `IntersectionObserver` binding if needed.
2. Create an internal observer registry keyed by:
   - root element identity
   - threshold
   - root margin
3. Register each link element with a callback.
4. Unregister on effect cleanup.
5. Disconnect the shared observer when no elements remain for that observer key.
6. Add tests where possible, or a browser fixture if DOM observer behavior is hard to unit test.

### Validation

- Many links create one observer for shared options.
- Preload fires once per link.
- Cleanup removes callbacks and does not leak DOM nodes.
- Custom scroll root behavior still works.

### Risks

- Root element identity is awkward as a dictionary key. A JS helper may be cleaner than doing all registry logic in ReScript.
- Early preloading can increase network usage. Defaults should be measured.

## 9. Replace Reflective Disposable Extraction

### Current State

Prepared route results are recursively scanned for objects with a `dispose` function:

- `packages/rescript-relay-router/src/RelayRouter__Internal.res`

This lets route prepare functions return Relay preloaded query refs without explicit disposal wiring. It is ergonomic but implicit and potentially expensive for complex prepared objects.

It also means any object with a `dispose` function can be treated as a resource by convention.

### Opportunity

Introduce an explicit disposal API while preserving the current reflective fallback for compatibility.

Possible renderer API:

```rescript
type preparedResult<'prepared> = {
  prepared: 'prepared,
  disposables: array<unit => unit>,
}
```

or:

```rescript
makeRenderer(
  ~prepare,
  ~disposePrepared=?,
  ~render,
)
```

The second option avoids wrapping existing prepare returns but still gives explicit control.

### Implementation Steps

1. Extend internal renderer type with optional disposal hook.
2. Update generated `makeRenderer` binding to accept it.
3. In `prepareRoute`, prefer explicit disposables if supplied.
4. Keep `extractDisposables` as fallback.
5. Add tests:
   - explicit disposal runs on unmount
   - reflective fallback still works
   - old disposables are delayed until new query refs can be used by React
6. Document the recommended API for complex prepared values.

### Validation

- Existing route renderers keep working.
- New explicit disposal path avoids recursive object walking.
- Relay preloaded query refs are still disposed correctly.

### Risks

- The API may become noisier for users.
- Having both explicit and reflective behavior can be confusing. Docs should state precedence clearly.

## 10. Reduce Repeated Query Decoding

### Current State

Query params are parsed and decoded in several places:

- During route preparation.
- In generated route `useQueryParams` hooks.
- In link-preservation helpers.
- In route key generation.

Generated code decodes each query param independently. Array params sometimes use memo dependencies based on joined strings.

### Opportunity

Cache parsed query params and route-specific decoded query records per location/search string.

Possible design:

- Router computes `QueryParams.t` once per navigation.
- Router exposes the parsed `QueryParams.t` on current route entry or a query-param store.
- Generated route modules expose a decoder identity/key.
- Runtime memoizes decoded query records by `(search, routeName)` or `(search, decoderId)`.

The simpler near-term improvement is to reuse parsed `QueryParams.t` across route preparation and route hooks where the same search string is already available.

### Implementation Steps

1. Audit every `QueryParams.parse` call.
2. Add a small query parse cache keyed by raw `search`.
3. Use it in:
   - `Router.make`
   - `runOnEachRouteMatch`
   - `useSetQueryParams`
   - `useMakeLinkWithPreservedPath`
   - generated `useQueryParams`, if practical
4. Consider generated decoder caching as a second phase.
5. Add tests for query param updates and shallow navigation.

### Validation

- Query hooks still update on every search change.
- Repeated parsing drops in an instrumented test.
- Query array behavior remains unchanged.
- Default-value serialization still works.

### Risks

- `URLSearchParams` is mutable. If cached, callers must not mutate shared instances unexpectedly.
- The cache may need to return fresh copies for mutation-heavy call sites.
- Over-caching can introduce subtle stale-state bugs.

## Suggested Work Slicing

These work items can be picked up independently:

1. Location subscription store:
   - contained React runtime change
   - needs care around shallow navigation
2. Named root-tree rendering:
   - codegen and runtime scoping change
   - useful for multi-entry apps, admin surfaces, and embedded route renderers
3. Link observer pooling:
   - contained link component change
   - needs browser behavior validation
4. Explicit disposal API:
   - API evolution
   - should preserve fallback behavior
5. Prepare freshness policy:
   - highest semantic risk
   - should start behind opt-in policy
6. Lazy route declaration split:
   - larger architecture project
   - should start with bundle analysis and a PoC
7. Renderer chunk boundary verification:
   - measurement-first
   - may become a small scaffold generation change
8. Query decoding cache:
   - useful after route-key and location-store work clarify ownership of `search`

## Recommended Starting Order

Start with:

1. Named root-tree rendering, if multi-entry apps or embedded surfaces are a near-term target.
2. Centralized location subscriptions.
3. Reduce repeated query decoding.
4. Prepare freshness policy, behind an explicit opt-in.
5. Renderer chunk boundary verification before any larger lazy route declaration split.

That order improves route-tree boundaries for multi-entry rendering, then reduces router
subscription and query parsing churn before touching Relay freshness semantics. The larger lazy
declaration split should wait for bundle analysis so the architectural work is justified by
measured chunk output.
