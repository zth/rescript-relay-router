module TodosList = %relay.deferredComponent(TodosList.make)

let renderer = Route__Root__Todos_route.makeRenderer(
  ~prepareCode=_ => [TodosList.preload()],
  ~prepare=({environment, showAll}) => {
    TodosListQuery_graphql.load(
      ~environment,
      ~fetchPolicy=StoreOrNetwork,
      ~variables={
        first: Some(
          switch showAll->Belt.Option.getWithDefault(false) {
          | false => 1
          | true => 5
          },
        ),
      },
      (),
    )
  },
  ~render=({prepared, childRoutes}) => {
    <TodosList queryRef=prepared> {childRoutes} </TodosList>
  },
  (),
)
