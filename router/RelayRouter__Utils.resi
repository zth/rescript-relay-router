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

/**
 * For internal use only.
 *
 * This is a non-existent string transformation function that will be replaced
 * by the ReScript Vite plugin at build time to turn `@rescriptModule/` package
 * references into their compiled JS asset paths.
 */
@live @val external transformReScriptModuleToJsPath : string => string = "__transformReScriptModuleToJsPath"
