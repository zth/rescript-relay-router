let renderer: Routes.Root.Todos.Single.Route.routeRenderer<'prepared> = {
  prepare: ({environment, params: {showMore, todoId}}) => {
    SingleTodoQuery_graphql.load(
      ~environment,
      ~fetchPolicy=StoreOrNetwork,
      ~variables={
        id: todoId,
        showMore: showMore->Option.getWithDefault(false),
      },
    )
  },
  render: ({prepared}) => {
    <SingleTodo queryRef=prepared />
  },
}
