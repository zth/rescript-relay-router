type prepareProps

module RouteRenderer: {
  type t
}

type suspenseEnabledHolder<'thing> = NotInitiated | Pending(promise<'thing>) | Loaded('thing)

type loadedRouteRenderer = suspenseEnabledHolder<RouteRenderer.t>

type preparedContainer = {
  disposables: array<unit => unit>,
  render: RelayRouter.Types.renderRouteFn,
  mutable timeout: option<Js.Global.timeoutId>,
}

type makePrepareProps = (
  ~environment: RescriptRelay.Environment.t,
  ~pathParams: Js.Dict.t<string>,
  ~queryParams: RelayRouter.Bindings.QueryParams.t,
  ~location: RelayRouter__History.location,
) => prepareProps

let doLoadRouteRenderer: (
  unit => promise<RouteRenderer.t>,
  ~routeName: Belt.HashMap.String.key,
  ~loadedRouteRenderers: Belt.HashMap.String.t<suspenseEnabledHolder<RouteRenderer.t>>,
) => promise<unit>

let preloadCode: (
  ~loadedRouteRenderers: Belt.HashMap.String.t<suspenseEnabledHolder<RouteRenderer.t>>,
  ~routeName: Belt.HashMap.String.key,
  ~loadRouteRenderer: unit => promise<unit>,
  ~makePrepareProps: makePrepareProps,
  ~environment: RescriptRelay.Environment.t,
  ~pathParams: Js.Dict.t<string>,
  ~queryParams: RelayRouter.Bindings.QueryParams.t,
  ~location: RelayRouter__History.location,
) => promise<array<RelayRouter__Types.preloadAsset>>

type prepareAssets = {
  getPrepared: (~routeKey: Belt.HashMap.String.key) => option<preparedContainer>,
  prepareRoute: (
    ~environment: RescriptRelay.Environment.t,
    ~pathParams: Js.Dict.t<string>,
    ~queryParams: RelayRouter.Bindings.QueryParams.t,
    ~location: RelayRouter__History.location,
    ~makePrepareProps: (
      ~environment: RescriptRelay.Environment.t,
      ~pathParams: Js.Dict.t<string>,
      ~queryParams: RelayRouter.Bindings.QueryParams.t,
      ~location: RelayRouter__History.location,
    ) => prepareProps,
    ~makeRouteKey: (
      ~pathParams: Js.Dict.t<string>,
      ~queryParams: RelayRouter.Bindings.QueryParams.t,
    ) => string,
    ~getPrepared: (~routeKey: Belt.HashMap.String.key) => option<preparedContainer>,
    ~routeName: string,
    ~loadRouteRenderer: unit => promise<unit>,
    ~intent: RelayRouter__Types.prepareIntent,
  ) => RelayRouter.Types.preparedRoute,
}

let makePrepareAssets: (
  ~loadedRouteRenderers: Belt.HashMap.String.t<suspenseEnabledHolder<RouteRenderer.t>>,
  ~prepareDisposeTimeout: int,
) => prepareAssets
