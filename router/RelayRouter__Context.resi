module Provider : {
  let make : React.component<{"value": RelayRouter__Types.routerContext, "children": React.element}>

  let makeProps : (~value : RelayRouter__Types.routerContext, ~children: React.element, ()) => {"value": RelayRouter__Types.routerContext, "children": React.element}
}

let useRouterContext : unit => RelayRouter__Types.routerContext;
