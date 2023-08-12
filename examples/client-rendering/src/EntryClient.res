let boot = () => {
  let routes = RouteDeclarations.make()
  let routerEnvironment = RelayRouter.RouterEnvironment.makeBrowserEnvironment()

  Console.log("[debug] Doing boot")

  
    let (_, routerContext) = RelayRouter.Router.make(
      ~routes,
      ~environment=RelayEnv.environment,
      ~routerEnvironment,
      ~preloadAsset=RelayRouter.AssetPreloader.makeClientAssetPreloader(RelayEnv.preparedAssetsMap),
    )

    ReactDOMExperimental.renderConcurrentRootAtElementWithId(
      <App environment=RelayEnv.environment routerContext />, 
      "root"
    )
  
}

boot()

