let renderer: Routes.Root.Route.routeRenderer<'prepared> = {
  prepare: ({environment}) => {
    LayoutQuery_graphql.load(~environment, ~variables=(), ~fetchPolicy=StoreOrNetwork)
  },
  render: props => {
    <Layout queryRef=props.prepared> {props.childRoutes} </Layout>
  },
}
