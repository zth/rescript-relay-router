let boot = () => {
  let routes = RouteDeclarations.make()
  let routerEnvironment = RelayRouter.RouterEnvironment.makeBrowserEnvironment()

  Js.log("[debug] Doing boot")

  RelaySSRUtils.bootOnClient(~rootElementId="root", ~render=() => {
    let (_, routerContext, _) = RelayRouter.Router.make(
      ~routes,
      ~environment=RelayEnv.environment,
      ~routerEnvironment,
    )

    <Main environment=RelayEnv.environment routerContext />
  })
}

boot()
