module TododsFragment = %relay(`
  fragment TodosListDisplay_todos on Query
  @refetchable(queryName: "TodosListDisplayPaginationQuery")
  @argumentDefinitions(
    first: { type: "Int", defaultValue: 1 }
    
  ) {
    todosConnection(first: $first) {
      edges {
        node {
          ...TodosListItem_todo
          id
        }
      }
    }
  }
`)

@react.component
let make = (~todos) => {
  let (todos, refetch) = TododsFragment.useRefetchable(todos)
  let (_, startTransition) = ReactExperimental.useTransition()
  let routerContext = RelayRouter.useRouterContext()
  let {queryParams} = Routes.Root.Todos.Route.useQueryParams()

  // TODO: Matches route, is on right route, etc
  let makeRefetch = queryParams => {
    let _ = refetch(
      ~variables=TododsFragment.makeRefetchVariables(
        ~first=switch queryParams.Routes.Root.Todos.Route.showAll->Belt.Option.getWithDefault(
          false,
        ) {
        | false => Some(1)
        | true => Some(5)
        },
        (),
      ),
      (),
    )
  }

  React.useEffect0(() => {
    let matched = RelayRouter__Internal.matchPath(
      Routes.Root.Todos.Route.routePattern,
      routerContext.get().location.pathname,
    )

    switch matched {
    | Some(_) =>
      routerContext.registerRouteHandler(~handler=loc => {
        Js.log(`Route handler triggered ${Js.Date.now()->Belt.Float.toString}`)
        startTransition(() => {
          let queryParams = Routes.Root.Todos.Route.parseQueryParams(loc.search)
          makeRefetch(queryParams)
        })
      }, ~handlerId="TodoListDisplay", ~routeName=Routes.Root.Todos.Route.routeName)
      Some(
        () => {
          routerContext.unregisterRouteHandler("TodoListDisplay")
        },
      )
    | _ => None
    }
  })

  <div>
    <RelayRouter.Link to_={Routes.Root.Todos.Route.makeLink(~showAll=true, ())}>
      {React.string("Show all")}
    </RelayRouter.Link>
    <button
      onClick={_ => {
        let showAll = switch queryParams.showAll->Belt.Option.getWithDefault(false) {
        | false => true
        | true => false
        }
        startTransition(() => {
          switch Routes.Root.Todos.Route.makeLink(~showAll, ()) {
          | AppRoute({url}) =>
            makeRefetch({showAll: Some(showAll)})
            routerContext.history->RelayRouter__History.pushWithState(
              url,
              {shallow: Some(true), handlerId: "TodoListDisplay"},
            )
          | _ => ()
          }
        })
      }}>
      {React.string("push state")}
    </button>
    {todos.todosConnection.edges
    ->Belt.Option.getWithDefault([])
    ->Belt.Array.keepMap(edge =>
      switch edge {
      | Some({node: Some(node)}) => Some(node)
      | _ => None
      }
    )
    ->Belt.Array.map(todo => <TodosListItem todo={todo.fragmentRefs} key=todo.id />)
    ->React.array}
  </div>
}
