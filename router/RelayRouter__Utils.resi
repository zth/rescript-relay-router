@live
let childRouteHasContent: React.element => bool

type routerHelpers = {
  push: string => unit,
  replace: string => unit,
  preload: (string, ~priority: RelayRouter__Types.preloadPriority=?, unit) => unit,
  preloadCode: (string, ~priority: RelayRouter__Types.preloadPriority=?, unit) => unit,
}

@live
let useRouter: unit => routerHelpers

@live
let useLocation: unit => RelayRouter__Bindings.History.location

@live
let isRouteActive: (~pathname: string, ~routePattern: string, ~exact: bool=?, unit) => bool

@live
let useIsRouteActive: (~href: string, ~routePattern: string, ~exact: bool=?, unit) => bool

let makePlaceholderChunkName: string => RelayRouter__Types.placeholderChunkName
external placeholderChunkNameToChunkString: RelayRouter__Types.placeholderChunkName => string =
  "%identity"
