let renderer: Route__Root__Todos_route.routeRenderer<'prepared> = {
  prepare: ({environment}) => {
    TodosListQuery_graphql.load(~environment, ~fetchPolicy=StoreOrNetwork, ~variables=())
  },
  render: ({prepared, childRoutes}) => {
    <TodosList queryRef=prepared> {childRoutes} </TodosList>
  },
}
