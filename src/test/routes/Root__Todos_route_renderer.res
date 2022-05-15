module TodosList = %relay.deferredComponent(TodosList.make)

let renderer = Route__Root__Todos_route.makeRenderer(
  ~prepareCode=_ => [TodosList.preload()],
  ~prepare=_ => {
    ()
  },
  ~render=_ => {
    <TodosList />
  },
  (),
)
