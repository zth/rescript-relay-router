module SingleUser = %relay.deferredComponent(SingleUser.make)

let renderer = Route__Root__Users__Single_route.makeRenderer(
  ~prepareCode=_ => [SingleUser.preload()],
  ~prepare=_ => {
    ()
  },
  ~render=props => {
    <div style={ReactDOM.Style.make(~height="600px", ())}>
      {React.string(props.userId)}
      <SingleUser id=props.userId />
      <RelayRouterLink
        to_={Routes.Root.Users.Route.makeLink()} preloadCode=OnInView preloadData=OnIntent>
        {React.string("to overview")}
      </RelayRouterLink>
    </div>
  },
  (),
)
