let renderer = Route__Root__PathParamsOnly_route.makeRenderer(
  ~prepare=({environment}) => {
    LayoutQuery_graphql.load(~environment, ~variables=(), ~fetchPolicy=StoreOrNetwork)
  },
  ~render=props => {
    <Layout queryRef=props.prepared> {props.childRoutes} </Layout>
  },
)
