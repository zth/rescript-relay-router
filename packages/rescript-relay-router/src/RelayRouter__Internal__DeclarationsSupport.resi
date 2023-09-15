type prepareProps<'params> = {
  environment: RescriptRelay.Environment.t,
  location: RelayRouter.History.location,
  params: 'params,
}

type renderProps<'params, 'prepared> = {
  childRoutes: React.element,
  prepared: 'prepared,
  environment: RescriptRelay.Environment.t,
  location: RelayRouter.History.location,
  params: 'params,
}

module RouteRenderer: {
  type t<'params, 'prepared> = {
    prepare: prepareProps<'params> => 'prepared,
    prepareCode?: prepareProps<'params> => array<RelayRouter.Types.preloadAsset>,
    render: renderProps<'params, 'prepared> => React.element,
  }
}

@unboxed type rec routeRenderer = RouteRenderer(RouteRenderer.t<'params, 'prepared>): routeRenderer

type opaquePrepareProps

external unsafe_toPrepareProps: prepareProps<'a> => prepareProps<'b> = "%identity"

type suspenseEnabledHolder<'thing> = NotInitiated | Pending(promise<'thing>) | Loaded('thing)

type loadedRouteRenderer = suspenseEnabledHolder<routeRenderer>

type preparedContainer = {
  disposables: array<unit => unit>,
  render: RelayRouter.Types.renderRouteFn,
  mutable timeout: option<Js.Global.timeoutId>,
}

type makePrepareProps<'params> = (
  ~environment: RescriptRelay.Environment.t,
  ~pathParams: Js.Dict.t<string>,
  ~queryParams: RelayRouter.Bindings.QueryParams.t,
  ~location: RelayRouter__History.location,
) => prepareProps<'params>

let doLoadRouteRenderer: (
  unit => promise<RouteRenderer.t<'params, 'prepared>>,
  ~routeName: Belt.HashMap.String.key,
  ~loadedRouteRenderers: Belt.HashMap.String.t<loadedRouteRenderer>,
) => promise<unit>

let preloadCode: (
  ~loadedRouteRenderers: Belt.HashMap.String.t<loadedRouteRenderer>,
  ~routeName: Belt.HashMap.String.key,
  ~loadRouteRenderer: unit => promise<unit>,
  ~makePrepareProps: makePrepareProps<'params>,
  ~environment: RescriptRelay.Environment.t,
  ~pathParams: Js.Dict.t<string>,
  ~queryParams: RelayRouter.Bindings.QueryParams.t,
  ~location: RelayRouter__History.location,
) => promise<array<RelayRouter__Types.preloadAsset>>

type prepareAssets<'params> = {
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
    ) => prepareProps<'params>,
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
  ~loadedRouteRenderers: Belt.HashMap.String.t<loadedRouteRenderer>,
  ~prepareDisposeTimeout: int,
) => prepareAssets<'params>
