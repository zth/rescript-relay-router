let renderer = Routes.Root.Todos.Inactive.Route.makeRenderer(
  ~prepare=_ => {
    ()
  },
  ~render=_ => {
    React.null
  },
  (),
)
