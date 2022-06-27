type stream

@module("react-dom/server")
external renderToPipeableStream: (React.element, 'opts) => stream = "renderToPipeableStream"

@live
let getStream = (
  ~url,
  ~options,
  ~onResponseReceived,
  ~onQueryInitiated,
  ~onEmitPreloadAsset: (. {..}) => unit,
) => {
  let preloadAsset = asset => {
    switch asset {
    | RelayRouter.Types.Component({chunk, moduleName}) =>
      onEmitPreloadAsset(. {"type": "component", "chunk": chunk, "moduleName": moduleName})
    | Image(_) => () // onEmitPreloadAsset(. {"type": "image", "url": url})
    }
  }

  let environment = RelayEnv.makeServer(~onResponseReceived, ~onQueryInitiated)
  let routerEnvironment = RelayRouter.RouterEnvironment.makeServerEnvironment(~initialUrl=url)

  let routes = RouteDeclarations.make()

  let (_cleanup, routerContext) = RelayRouter.Router.make(
    ~routes,
    ~environment,
    ~routerEnvironment,
    ~preloadAsset={
      asset =>
        switch asset {
        | #JsModule(moduleName, chunk) =>
          onEmitPreloadAsset(. {"type": "component", "chunk": chunk, "moduleName": moduleName})
        }
    },
    (),
  )
  renderToPipeableStream(
    <RelaySSRUtils.AssetRegisterer.Provider value=preloadAsset>
      <Main environment routerContext />
    </RelaySSRUtils.AssetRegisterer.Provider>,
    options,
  )
}
