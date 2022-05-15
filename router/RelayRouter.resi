module RouterEnvironment: {
  type t
  let makeBrowserEnvironment: unit => t
  let makeServerEnvironment: (~initialUrl: string) => t
}

let runAtPriority: (
  RelayRouterTypes.callback,
  ~priority: RelayRouterTypes.preloadPriority,
) => option<unit => unit>

module Router: {
  let make: (
    ~routes: array<RelayRouterTypes.route>,
    ~routerEnvironment: RouterEnvironment.t,
    ~environment: RescriptRelay.Environment.t,
  ) => (RelayRouterTypes.cleanupFn, RelayRouterTypes.routerContext)
}

module Provider: {
  let make: React.component<{"children": React.element, "value": RelayRouterTypes.routerContext}>

  let makeProps: (
    ~value: RelayRouterTypes.routerContext,
    ~children: React.element,
    unit,
  ) => {"children": React.element, "value": RelayRouterTypes.routerContext}
}

let useRouterContext: unit => RelayRouterTypes.routerContext

module RouteRenderer: {
  @react.component @live
  let make: (
    ~renderPending: bool => React.element=?,
    ~renderFallback: unit => React.element=?,
    unit,
  ) => React.element
}

let useRegisterPreloadedAsset: RelayRouterTypes.preloadAsset => unit
