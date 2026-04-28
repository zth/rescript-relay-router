open RescriptRelayRouterCli__Types
open RescriptRelayRouterCli__Bindings

module Utils = RescriptRelayRouterCli__Utils

let pathRelativeToCwd = path => Path.relative(Process.cwd(), path)

let routeUrl = (route: printableRoute) => route.path->RoutePath.getFullRoutePath

let queryParamsObject = (route: printableRoute) => {
  let queryParams = Dict.make()
  let queryParamKeys =
    route.queryParams
    ->Dict.toArray
    ->Array.map(((key, _)) => key)
  queryParamKeys->Array.sort(String.localeCompare)

  queryParamKeys->Array.forEach(key => {
    queryParams->Dict.set(key, JSON.String(`:${key}`))
  })

  queryParams
}

let routeRendererPath = (~config, route: printableRoute) =>
  Utils.pathInRoutesFolder(~config, ~fileName=route.name->RouteName.getRouteRendererFileName)
  ->pathRelativeToCwd

let routeFilePath = (~config, route: printableRoute) =>
  Utils.pathInRoutesFolder(~config, ~fileName=route.sourceFile)->pathRelativeToCwd

let rec flattenRoutes = (routes: array<printableRoute>): array<printableRoute> => {
  let allRoutes = []

  routes->Array.forEach(route => {
    allRoutes->Array.push(route)
    route.children->flattenRoutes->Array.forEach(route => allRoutes->Array.push(route))
  })

  allRoutes
}

let urlFromDumpedRoute = route => {
  switch route->Dict.get("url") {
  | Some(JSON.String(url)) => url
  | _ => ""
  }
}

let sortRoutes = (routes, ~sortOrder) => {
  switch sortOrder {
  | DefinitionOrder => ()
  | Alphabetic =>
    routes->Array.sort((a, b) =>
      String.localeCompare(a->urlFromDumpedRoute, b->urlFromDumpedRoute)
    )
  }
}

let dump = (~routes, ~config, ~options: dumpRoutesOptions) => {
  let routes =
    routes
    ->flattenRoutes
    ->Array.map(route => {
      let item = Dict.make()
      item->Dict.set("url", route->routeUrl->JSON.String)

      if options.includeQueryParams {
        item->Dict.set("queryParams", route->queryParamsObject->JSON.Object)
      }

      if options.includeName {
        item->Dict.set("name", route.name->RouteName.getFullRouteName->JSON.String)
      }

      if options.includeRouteRendererPath {
        item->Dict.set("routeRendererPath", route->routeRendererPath(~config)->JSON.String)
      }

      if options.includeRouteFilePath {
        item->Dict.set("routeFilePath", route->routeFilePath(~config)->JSON.String)
      }

      item
    })

  routes->sortRoutes(~sortOrder=options.sortOrder)
  routes
}

let run = (~options, ~config) => {
  let (routes, _routeNamesDict) = Utils.readRouteStructure(config)
  Console.log(
    dump(~routes, ~config, ~options)
    ->Array.map(route => JSON.Object(route))
    ->JSON.Array
    ->JSON.stringify(~space=2),
  )
}
