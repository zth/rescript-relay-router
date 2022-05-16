let renderer = Route__Root__Users_route.makeRenderer(
  ~prepare=_ => {
    Js.log("preparing...!")
    {
      "someTest": true,
      "dispose": (. ()) => {
        Js.log("doing dispose")
      },
      "nested": {
        "dispose": (. ()) => {
          Js.log("doing nested dispose")
        },
      },
    }
  },
  ~render=props => {
    let {setParams} = Routes.Root.Users.Route.useQueryParams()

    <div
      style={ReactDOM.Style.make(
        ~height="1500px",
        ~backgroundColor="tomato",
        ~display="flex",
        ~alignItems="flex-end",
        ~paddingBottom="100px",
        (),
      )}>
      {switch props.search {
      | Some(search) => React.string(search)
      | None => React.string("no seearch")
      }}
      <RelayRouter.Link to_={Routes.Root.Users.Single.Route.makeLink(~userId="123", ())}>
        {React.string("To a user")}
      </RelayRouter.Link>
      <button
        onClick={_ => {
          setParams(~setter=current => {
            ...current,
            search: Js.Math.random()->Belt.Float.toString->Some,
          }, ())
        }}>
        {React.string("Set search")}
      </button>
      {props.childRoutes}
    </div>
  },
  (),
)
