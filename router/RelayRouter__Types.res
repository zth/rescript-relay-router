open RelayRouter__Bindings

type renderRouteFn = (. ~childRoutes: React.element) => React.element

@live
type preloadPriority = High | Default | Low

type preloadComponentAsset = {@as("__$rescriptChunkName__") chunk: string}

@live
type preloadAsset =
  | Component(preloadComponentAsset)
  | Image({url: string})

type preloadAssetFn = (preloadAsset, ~priority: preloadPriority) => unit
type preparedRoute = {routeKey: string, render: renderRouteFn}

type prepareIntent = Render | Preload

@live
type rec route = {
  path: string,
  name: string,
  @as("__$rescriptChunkName__") chunk: string,
  loadRouteRenderer: unit => Js.Promise.t<unit>,
  preloadCode: (
    . ~environment: RescriptRelay.Environment.t,
    ~pathParams: Js.Dict.t<string>,
    ~queryParams: RelayRouter__Bindings.QueryParams.t,
    ~location: RelayRouter__Bindings.History.location,
  ) => Js.Promise.t<array<preloadAsset>>,
  prepare: (
    . ~environment: RescriptRelay.Environment.t,
    ~pathParams: Js.Dict.t<string>,
    ~queryParams: QueryParams.t,
    ~location: RelayRouter__Bindings.History.location,
    ~intent: prepareIntent,
  ) => preparedRoute,
  children: array<route>,
}

type routeMatch = {
  params: Js.Dict.t<string>,
  route: route,
}

type preparedMatch = {routeKey: string, render: renderRouteFn}

type currentRouterEntry = {
  location: History.location,
  preparedMatches: array<preparedMatch>,
}

type subFn = currentRouterEntry => unit
type unsubFn = unit => unit
type cleanupFn = unit => unit
type callback = unit => unit

type routerEvent =
  | OnBeforeNavigation({currentLocation: RelayRouter__Bindings.History.location})
  | RestoreScroll(RelayRouter__Bindings.History.location)
  | OnRouteWillUnmount({routeKey: string})

type onRouterEventFn = routerEvent => unit

@live
type routerContext = {
  preload: (string, ~priority: preloadPriority=?, unit) => unit,
  preloadCode: (string, ~priority: preloadPriority=?, unit) => unit,
  preloadAsset: preloadAssetFn,
  get: unit => currentRouterEntry,
  subscribe: subFn => unsubFn,
  history: History.t,
  subscribeToEvent: onRouterEventFn => unsubFn,
  postRouterEvent: routerEvent => unit,
}

@live
type streamedEntry = {
  id: string,
  response: Js.Json.t,
  final: bool,
}

@live
type setQueryParamsMode = Push | Replace
