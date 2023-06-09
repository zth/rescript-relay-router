open RelayRouter__Bindings

type renderRouteFn = (~childRoutes: React.element) => React.element

@live
type preloadPriority = High | Default | Low

type preloadComponentAsset = {
  @as("__$rescriptChunkName__") chunk: string,
  load: unit => unit,
}

@live
type preloadAsset =
  | Component(preloadComponentAsset)
  | Image({url: string})
  | Style({url: string})

type preloadFn = (~priority: preloadPriority=?, string) => unit
type preloadCodeFn = (~priority: preloadPriority=?, string) => unit
type preloadAssetFn = (~priority: preloadPriority, preloadAsset) => unit
type preparedRoute = {routeKey: string, render: renderRouteFn}

type prepareIntent = Render | Preload

@live
type rec route = {
  path: string,
  name: string,
  @as("__$rescriptChunkName__") chunk: string,
  loadRouteRenderer: unit => promise<unit>,
  preloadCode: (
    ~environment: RescriptRelay.Environment.t,
    ~pathParams: Js.Dict.t<string>,
    ~queryParams: RelayRouter__Bindings.QueryParams.t,
    ~location: RelayRouter__History.location,
  ) => promise<array<preloadAsset>>,
  prepare: (
    ~environment: RescriptRelay.Environment.t,
    ~pathParams: Js.Dict.t<string>,
    ~queryParams: QueryParams.t,
    ~location: RelayRouter__History.location,
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
  location: RelayRouter__History.location,
  preparedMatches: array<preparedMatch>,
}

type subFn = currentRouterEntry => unit
type unsubFn = unit => unit
type cleanupFn = unit => unit
type callback = unit => unit

type routerEvent =
  | OnBeforeNavigation({currentLocation: RelayRouter__History.location})
  | RestoreScroll(RelayRouter__History.location)
  | OnRouteWillUnmount({routeKey: string})

type onRouterEventFn = routerEvent => unit

@live
type routerContext = {
  preload: preloadFn,
  preloadCode: preloadCodeFn,
  preloadAsset: preloadAssetFn,
  get: unit => currentRouterEntry,
  subscribe: subFn => unsubFn,
  history: RelayRouter__History.t,
  subscribeToEvent: onRouterEventFn => unsubFn,
  postRouterEvent: routerEvent => unit,
  markNextNavigationAsShallow: unit => unit,
}

@live
type streamedEntry = {
  id: string,
  response: Js.Json.t,
  final: bool,
}

@live
type setQueryParamsMode = Push | Replace
