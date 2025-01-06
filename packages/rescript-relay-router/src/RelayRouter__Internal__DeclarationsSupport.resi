type prepareProps

module RouteRenderer: {
  type t
}

type suspenseEnabledHolder<'thing> = NotInitiated | Pending(promise<'thing>) | Loaded('thing)

type loadedRouteRenderer = suspenseEnabledHolder<RouteRenderer.t>

type preparedContainer = {
  disposables: array<unit => unit>,
  render: RelayRouter.Types.renderRouteFn,
  mutable timeout: option<timeoutId>,
}

type makePrepareProps = (
  ~environment: RescriptRelay.Environment.t,
  ~pathParams: dict<string>,
  ~queryParams: RelayRouter.Bindings.QueryParams.t,
  ~location: RelayRouter__History.location,
) => prepareProps

let doLoadRouteRenderer: (
  unit => promise<RouteRenderer.t>,
  ~routeName: string,
  ~loadedRouteRenderers: Map.t<string, suspenseEnabledHolder<RouteRenderer.t>>,
) => promise<unit>

let preloadCode: (
  ~loadedRouteRenderers: Map.t<string, suspenseEnabledHolder<RouteRenderer.t>>,
  ~routeName: string,
  ~loadRouteRenderer: unit => promise<unit>,
  ~makePrepareProps: makePrepareProps,
  ~environment: RescriptRelay.Environment.t,
  ~pathParams: dict<string>,
  ~queryParams: RelayRouter.Bindings.QueryParams.t,
  ~location: RelayRouter__History.location,
) => promise<array<RelayRouter__Types.preloadAsset>>

type prepareAssets = {
  getPrepared: (~routeKey: string) => option<preparedContainer>,
  prepareRoute: (
    ~environment: RescriptRelay.Environment.t,
    ~pathParams: dict<string>,
    ~queryParams: RelayRouter.Bindings.QueryParams.t,
    ~location: RelayRouter__History.location,
    ~makePrepareProps: (
      ~environment: RescriptRelay.Environment.t,
      ~pathParams: dict<string>,
      ~queryParams: RelayRouter.Bindings.QueryParams.t,
      ~location: RelayRouter__History.location,
    ) => prepareProps,
    ~makeRouteKey: (
      ~pathParams: dict<string>,
      ~queryParams: RelayRouter.Bindings.QueryParams.t,
    ) => string,
    ~getPrepared: (~routeKey: string) => option<preparedContainer>,
    ~routeName: string,
    ~loadRouteRenderer: unit => promise<unit>,
    ~intent: RelayRouter__Types.prepareIntent,
  ) => RelayRouter.Types.preparedRoute,
}

let makePrepareAssets: (
  ~loadedRouteRenderers: Map.t<string, suspenseEnabledHolder<RouteRenderer.t>>,
  ~prepareDisposeTimeout: int,
) => prepareAssets
