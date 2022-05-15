let (_, routerContext) = RelayRouter.Router.make(
  ~routes=RouteDeclarations.make(),
  ~environment=RelayEnv.environment,
  ~routerEnvironment=RelayRouter.RouterEnvironment.makeBrowserEnvironment(),
)
