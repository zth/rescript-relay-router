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

  switch ReactDOM.querySelector("#root") {
  | Some(root) =>
    root
    ->ReactDOM.Client.createRoot
    ->ReactDOM.Client.Root.render(<App environment=RelayEnv.environment routerContext />)
  | None => Console.error("Could not find root element.")
  }
}

boot()
