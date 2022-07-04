type prepareProps

module RouteRenderer: {
  type t
}

type suspenseEnabledHolder<'thing> = NotInitiated | Pending(Js.Promise.t<'thing>) | Loaded('thing)

type loadedRouteRenderer = suspenseEnabledHolder<RouteRenderer.t>

type preparedContainer = {
  disposables: array<(. unit) => unit>,
  render: RelayRouter.Types.renderRouteFn,
  mutable timeout: option<Js.Global.timeoutId>,
}

type makePrepareProps = (
  . ~environment: RescriptRelay.Environment.t,
  ~pathParams: Js.Dict.t<string>,
  ~queryParams: RelayRouter.Bindings.QueryParams.t,
  ~location: RelayRouter.Bindings.History.location,
) => prepareProps

let doLoadRouteRenderer: (
  unit => Js.Promise.t<RouteRenderer.t>,
  ~routeName: Belt.HashMap.String.key,
  ~loadedRouteRenderers: Belt.HashMap.String.t<suspenseEnabledHolder<RouteRenderer.t>>,
) => Js.Promise.t<unit>

let preloadCode: (
  ~loadedRouteRenderers: Belt.HashMap.String.t<suspenseEnabledHolder<RouteRenderer.t>>,
  ~routeName: Belt.HashMap.String.key,
  ~loadRouteRenderer: unit => Js.Promise.t<unit>,
  ~makePrepareProps: makePrepareProps,
  ~environment: RescriptRelay.Environment.t,
  ~pathParams: Js.Dict.t<string>,
  ~queryParams: RelayRouter.Bindings.QueryParams.t,
  ~location: RelayRouter.Bindings.History.location,
) => Js.Promise.t<array<RelayRouter__Types.preloadAsset>>

type prepareAssets = {
  getPrepared: (~routeKey: Belt.HashMap.String.key) => option<preparedContainer>,
  prepareRoute: (
    . ~environment: RescriptRelay.Environment.t,
    ~pathParams: Js.Dict.t<string>,
    ~queryParams: RelayRouter.Bindings.QueryParams.t,
    ~location: RelayRouter.Bindings.History.location,
    ~makePrepareProps: (
      . ~environment: RescriptRelay.Environment.t,
      ~pathParams: Js.Dict.t<string>,
      ~queryParams: RelayRouter.Bindings.QueryParams.t,
      ~location: RelayRouter.Bindings.History.location,
    ) => prepareProps,
    ~makeRouteKey: (
      ~pathParams: Js.Dict.t<string>,
      ~queryParams: RelayRouter.Bindings.QueryParams.t,
    ) => string,
    ~getPrepared: (~routeKey: Belt.HashMap.String.key) => option<preparedContainer>,
    ~routeName: string,
    ~loadRouteRenderer: unit => Js.Promise.t<unit>,
  ) => RelayRouter.Types.preparedRoute,
}

let makePrepareAssets: (
  ~loadedRouteRenderers: Belt.HashMap.String.t<suspenseEnabledHolder<RouteRenderer.t>>,
  ~prepareDisposeTimeout: int,
) => prepareAssets
