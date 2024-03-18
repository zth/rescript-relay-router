@live
let childRouteHasContent: React.element => bool

@live
type routerHelpers = {
  push: (string, ~shallow: bool=?) => unit,
  replace: (string, ~shallow: bool=?) => unit,
  preload: RelayRouter__Types.preloadFn,
  preloadCode: RelayRouter__Types.preloadCodeFn,
}

@live
let useRouter: unit => routerHelpers

@live
let useLocation: unit => RelayRouter__History.location

@live
let isRouteActive: (~pathname: string, ~routePattern: string, ~exact: bool=?) => bool

@live
let useIsRouteActive: (~href: string, ~routePattern: string, ~exact: bool=?) => bool
