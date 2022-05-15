let renderer = Route__Root_route.makeRenderer(
  ~prepare=_ => {
    ()
  },
  ~render=props => {
    let mainContainerRef = React.useRef(Js.Nullable.null)

    <RelayRouterScroll.TargetScrollElement.Provider
      targetElementRef=mainContainerRef id="main-scroll-area">
      <main
        ref={ReactDOM.Ref.domRef(mainContainerRef)}
        style={ReactDOM.Style.make(~height="80vh", ~overflowY="auto", ())}>
        <RelayRouterLink to_={Routes.Root.Users.Route.makeLink(~count=123, ())}>
          {React.string("To users overview")}
        </RelayRouterLink>
        {props.childRoutes}
        <RelayRouterScroll.ScrollRestoration />
      </main>
    </RelayRouterScroll.TargetScrollElement.Provider>
  },
  (),
)
