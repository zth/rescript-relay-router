let renderer = Routes.Root.Todos.Single.Route.makeRenderer(
  ~prepare=({environment, showMore, todoId}) => {
    SingleTodoQuery_graphql.load(
      ~environment,
      ~fetchPolicy=StoreOrNetwork,
      ~variables={
        id: todoId,
        showMore: showMore->Option.getOr(false),
      },
    )
  },
  ~render=({prepared}) => {
    <SingleTodo queryRef=prepared />
  },
)
