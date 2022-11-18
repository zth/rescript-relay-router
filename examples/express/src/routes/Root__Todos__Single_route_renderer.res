module SingleTodo = %relay.deferredComponent(SingleTodo.make)

let renderer = Routes.Root.Todos.Single.Route.makeRenderer(
  ~prepareCode=_ => [SingleTodo.preload()],
  ~prepare=({environment, showMore, todoId}) => {
    SingleTodoQuery_graphql.load(
      ~environment,
      ~fetchPolicy=StoreOrNetwork,
      ~variables={
        id: todoId,
        showMore: showMore->Option.getWithDefault(false),
      },
      (),
    )
  },
  ~render=({prepared}) => {
    <SingleTodo queryRef=prepared />
  },
  (),
)
