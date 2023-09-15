let renderer: Routes.Root.Todos.Route.routeRenderer<'prepared> = {
  prepare: ({environment}) => {
    TodosListQuery_graphql.load(~environment, ~fetchPolicy=StoreOrNetwork, ~variables=())
  },
  render: ({prepared, childRoutes}) => {
    <TodosList queryRef=prepared> {childRoutes} </TodosList>
  },
}
