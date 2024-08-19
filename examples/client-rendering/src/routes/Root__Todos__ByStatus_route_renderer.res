let renderer = Routes.Root.Todos.ByStatus.Route.makeRenderer(
  ~prepare=_props => {
    ()
  },
  ~render=props => {
    <>
      {switch props.byStatus {
      | #completed => React.string("YES")
      | #"not-completed" => React.string("NOT COMPLETED")
      }}
      {React.string((props.byStatus :> string))}
    </>
  },
)
