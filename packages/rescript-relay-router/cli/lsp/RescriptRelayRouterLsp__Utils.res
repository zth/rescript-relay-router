open RescriptRelayRouterCli__Types

let findRouteWithName = (routeName, ~routeChildren) => {
  let res = ref(None)

  let rec searchForRouteWithName = (routeName, ~routeChildren) => {
    routeChildren->Array.forEach(routeEntry => {
      switch routeEntry {
      | RouteEntry(routeEntry) if routeEntry.name->RouteName.getFullRouteName == routeName =>
        res := Some(routeEntry)
      | RouteEntry({children: Some(children)})
      | Include({content: children}) =>
        routeName->searchForRouteWithName(~routeChildren=children)
      | _ => ()
      }
    })
  }

  routeName->searchForRouteWithName(~routeChildren)

  res.contents
}

let routeNameFromRouteRendererFileName = routeRendererFileName =>
  routeRendererFileName->String.split("_route_renderer.res")->Array.get(0)
