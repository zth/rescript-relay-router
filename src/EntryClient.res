let boot = () => {
  let routes = RouteDeclarations.make()
  let routerEnvironment = RelayRouter.RouterEnvironment.makeBrowserEnvironment()

  routes
  ->RelayRouter.getRouteMatches(~routerEnvironment)
  ->Belt.Array.map(({route}) => route.loadRouteRenderer())
  ->Js.Promise.all
  ->Js.Promise.then_(_ => {
    Js.log("[debug] Done loading route renderers, boot")

    RelaySSRUtils.bootOnClient(~rootElementId="root", ~render=() => {
      let (_, routerContext, _) = RelayRouter.Router.make(
        ~routes,
        ~environment=RelayEnv.environment,
        ~routerEnvironment,
      )

      <Main environment=RelayEnv.environment routerContext />
    })
    Js.Promise.resolve()
  }, _)
  ->ignore
}

boot()
