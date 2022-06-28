module Types = RelayRouter__Types
module Bindings = RelayRouter__Bindings
module Link = RelayRouter__Link
module Scroll = RelayRouter__Scroll

// TODO: This is now exposing RelayRouter internals because it's needed by the generated code.
module Internal = RelayRouter__Internal
module Utils = RelayRouter__Utils

module RouterEnvironment: {
  type t
  let makeBrowserEnvironment: unit => t
  let makeServerEnvironment: (~initialUrl: string) => t
}

module Router: {
  let make: (
    ~routes: array<Types.route>,
    ~routerEnvironment: RouterEnvironment.t,
    ~environment: RescriptRelay.Environment.t,
  ) => (Types.cleanupFn, Types.routerContext)
}

module Provider: {
  let make: React.component<{"children": React.element, "value": Types.routerContext}>

  let makeProps: (
    ~value: Types.routerContext,
    ~children: React.element,
    unit,
  ) => {"children": React.element, "value": Types.routerContext}
}

let useRouterContext: unit => Types.routerContext

module RouteRenderer: {
  @react.component @live
  let make: (
    ~renderPending: bool => React.element=?,
    ~renderFallback: unit => React.element=?,
    unit,
  ) => React.element
}

@live
let useRegisterPreloadedAsset: Types.preloadAsset => unit
