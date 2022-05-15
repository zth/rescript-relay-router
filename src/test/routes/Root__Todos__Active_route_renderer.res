let renderer = Routes.Root.Todos.Active.Route.makeRenderer(
  ~prepare=_ => {
    ()
  },
  ~render=_ => {
    React.null
  },
  (),
)
