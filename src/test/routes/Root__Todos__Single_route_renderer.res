let renderer = Routes.Root.Todos.Single.Route.makeRenderer(
  ~prepare=_ => {
    ()
  },
  ~render=_ => {
    React.null
  },
  (),
)
