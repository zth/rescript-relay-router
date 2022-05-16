type stream

@module("react-dom/server")
external renderToPipeableStream: (React.element, 'opts) => stream = "renderToPipeableStream"

@live
let getStream = (~url, ~options, ~onResponseReceived, ~onEmitPreloadAsset: (. {..}) => unit) => {
  let environment = RelayEnv.makeServer(~onResponseReceived)
  let routerEnvironment = RelayRouter.RouterEnvironment.makeServerEnvironment(~initialUrl=url)

  let routes = RouteDeclarations.make()

  let (_cleanup, routerContext) = RelayRouter.Router.make(~routes, ~environment, ~routerEnvironment)
  renderToPipeableStream(
    <RelaySSRUtils.AssetRegisterer.Provider
      value={asset => {
        switch asset {
        | RelayRouter.Types.Component({moduleName}) =>
          onEmitPreloadAsset(. {"type": "component", "moduleName": moduleName})
        | Image(_) => () // onEmitPreloadAsset(. {"type": "image", "url": url})
        }
      }}>
      <Main environment routerContext />
    </RelaySSRUtils.AssetRegisterer.Provider>,
    options,
  )
}
