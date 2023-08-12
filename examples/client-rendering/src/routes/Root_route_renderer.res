let renderer = Route__Root_route.makeRenderer(
  ~prepare=({environment}) => {
    LayoutQuery_graphql.load(~environment, ~variables=(), ~fetchPolicy=StoreOrNetwork)
  },
  ~render=props => {
    <Layout queryRef=props.prepared> {props.childRoutes} </Layout>
  },
)
