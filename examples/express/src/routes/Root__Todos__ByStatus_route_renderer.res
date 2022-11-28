let renderer = Routes.Root.Todos.ByStatus.Route.makeRenderer(
  ~prepare=props => {
    ()
  },
  ~render=props => {
    React.string((props.byStatus :> string))
  },
  (),
)
