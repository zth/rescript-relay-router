module Provider : {
  let make : React.component<{"value": RelayRouterTypes.routerContext, "children": React.element}>

  let makeProps : (~value : RelayRouterTypes.routerContext, ~children: React.element, ()) => {"value": RelayRouterTypes.routerContext, "children": React.element}
}

let useRouterContext : unit => RelayRouterTypes.routerContext;
