module Layout = %relay.deferredComponent(Layout.make)

let renderer = Route__Root_route.makeRenderer(
  ~prepareCode=_ => [Layout.preload()],
  ~prepare=({environment}) => {
    LayoutQuery_graphql.load(~environment, ~variables=(), ~fetchPolicy=StoreOrNetwork, ())
  },
  ~render=props => {
    <Layout queryRef=props.prepared> {props.childRoutes} </Layout>
  },
  (),
)
