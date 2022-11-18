let boot = () => {
  let routes = RouteDeclarations.make()
  let routerEnvironment = RelayRouter.RouterEnvironment.makeBrowserEnvironment()

  Console.log("[debug] Doing boot")

  RelaySSRUtils.bootOnClient(~render=() => {
    let (_, routerContext) = RelayRouter.Router.make(
      ~routes,
      ~environment=RelayEnv.environment,
      ~routerEnvironment,
      ~preloadAsset=RelayRouter.AssetPreloader.makeClientAssetPreloader(RelayEnv.preparedAssetsMap),
    )

    <App environment=RelayEnv.environment routerContext />
  })
}

boot()
