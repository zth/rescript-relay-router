let renderer = Route__Root__Todos_route.makeRenderer(
  ~prepare=({environment, childParams}) => {
    Console.log(childParams)
    TodosListQuery_graphql.load(~environment, ~fetchPolicy=StoreOrNetwork, ~variables=())
  },
  ~render=({prepared, childRoutes, childParams}) => {
    Console.log(childParams)
    <TodosList queryRef=prepared> {childRoutes} </TodosList>
  },
)
