module TodosList = %relay.deferredComponent(TodosList.make)

let renderer = Route__Root__Todos_route.makeRenderer(
  ~prepareCode=_ => [TodosList.preload()],
  ~prepare=({environment}) => {
    TodosListQuery_graphql.load(~environment, ~fetchPolicy=StoreOrNetwork, ~variables=(), ())
  },
  ~render=({prepared, childRoutes}) => {
    <TodosList queryRef=prepared> {childRoutes} </TodosList>
  },
  (),
)
