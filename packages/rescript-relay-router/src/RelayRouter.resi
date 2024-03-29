module Types = RelayRouter__Types
module Bindings = RelayRouter__Bindings
module Link = RelayRouter__Link
module Scroll = RelayRouter__Scroll
module AssetPreloader = RelayRouter__AssetPreloader
module NetworkUtils = RelayRouter__NetworkUtils
module PreloadInsertingStream = RelayRouter__PreloadInsertingStream
module Manifest = RelayRouter__Manifest
module History = RelayRouter__History

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
    ~preloadAsset: Types.preloadAssetFn,
  ) => (Types.cleanupFn, Types.routerContext)
}

module Provider: {
  let make: React.component<React.Context.props<RelayRouter__Types.routerContext>>
}

let useRouterContext: unit => Types.routerContext

module RouteRenderer: {
  @react.component @live
  let make: (~renderPending: bool => React.element=?) => React.element
}

@live
let useRegisterPreloadedAsset: Types.preloadAsset => unit
