# Centralized Location Subscriptions

## Decision

Centralize location subscriptions in `Router.make` and expose them on `routerContext` as
`getLocation` and `subscribeToLocation`.

## Why

Generated helpers such as `useQueryParams` and `useIsRouteActive` read through
`RelayRouter.Utils.useLocation`. Previously each hook consumer attached its own `history.listen`
subscription. Navigation-heavy layouts can render many consumers, so the router should own one
history listener and fan location snapshots out from a shared store.

This also separates two runtime concerns:

- route-entry subscribers update when prepared route matches change
- location subscribers update for every history location change, including shallow navigations

Shallow navigations intentionally skip route preparation, but query-param and active-route hooks
still need the new location snapshot.

Decision made by Codex on 2026-05-19.

## Verification

- Ran `yarn workspace rescript-relay-router build`.
- Ran `yarn workspace rescript-relay-router test`.
- Ran `yarn workspace @rescript-relay-router-example/client-rendering build:rescript`.
- Ran `yarn workspace @rescript-relay-router-example/client-rendering test`.
- Ran `yarn build`.
- Ran `yarn test`.
- Ran `yarn install --immutable`; it passed with the repo's existing peer dependency warnings.
- Ran `git diff --check`.

## Non-Goals

- No change to URL semantics.
- No change to generated route helper APIs.
- No attempt to make route-entry subscribers update on shallow navigation.
- No React transition scheduling changes for location subscribers.

## Known Blockers

None.
