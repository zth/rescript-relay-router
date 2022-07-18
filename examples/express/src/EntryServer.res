// TODO: Remove this if the TODO around line 70 is accepted.
// Otherwise move this into NodeJS bindings.
@send external writeToStream: (NodeJs.Stream.Writable.t, string) => unit = "write"

external transformAsWritable: RelayRouter.PreloadInsertingStream.Node.t => NodeJs.Stream.Writable.t =
  "%identity"

@live
let handleRequest = (~request, ~response, ~bootstrapModules) => {
  // TODO: request should be transformed from Express to native Request and the url should be retrieved from there.
  let initialUrl = request->Express.Request.originalUrl

  // Create our transform stream that will write assets that are loaded during rendering
  // into the stream. The output of this transformed stream is actually written to our
  // response.
  let transformOutputStream = RelayRouter.PreloadInsertingStream.Node.make(
    response->Express.Response.asWritable,
  )

  // On finish end our response stream to complete the response.
  transformOutputStream
  ->transformAsWritable
  ->NodeJs.Stream.fromWritable
  ->NodeJs.Stream.onFinish(() =>
    response->Express.Response.asWritable->NodeJs.Stream.fromWritable->NodeJs.Stream.end
  )

  // TODO: A default version of this should be provided by us/the router/the
  // framework, or in some way be made opaque to the dev in the default case.
  let preloadAsset: RelayRouter.Types.preloadAssetFn = (~priority as _, asset) =>
    switch asset {
    // TODO: If multiple lazy components are in the same chunk then this may load the same asset multiple times.
    | Component({chunk}) =>
      transformOutputStream->RelayRouter.PreloadInsertingStream.Node.onAssetPreload(j`<script type="module" src="$chunk" async></script>`)
    | Image({url}) =>
      transformOutputStream->RelayRouter.PreloadInsertingStream.Node.onAssetPreload(j`<link rel="preload" as="image" href="$url">`)
    }

  // TODO: Fix the RelayEnv.makeServer types so the extra function here isn't needed.
  let environment = RelayEnv.makeServer(
    ~onQuery=transformOutputStream->RelayRouter.PreloadInsertingStream.Node.onQuery,
    ~preloadAsset,
  )
  let routerEnvironment = RelayRouter.RouterEnvironment.makeServerEnvironment(~initialUrl)

  let routes = RouteDeclarations.make()

  let (cleanup, routerContext) = RelayRouter.Router.make(
    ~routes,
    ~environment,
    ~routerEnvironment,
    ~preloadAsset,
  )

  Promise.make((resolve, reject) => {
    let didError = ref(false)

    let stream = ref(None)
    stream :=
      ReactDOMServer.renderToPipeableStream(
        <App environment routerContext />,
        ReactDOMServer.renderToPipeableStreamOptions(
          // This renders as React is ready to start hydrating, and ensures that
          // if the client side bundle has already been downloaded, it starts
          // hydrating right away. If not, it lets the client bundle know that
          // React is ready to hydrate, and the client bundle starts hydration
          // as soon as it loads.
          ~bootstrapScriptContent="window.__READY_TO_BOOT ? window.__BOOT() : (window.__READY_TO_BOOT = true)",
          ~bootstrapModules,
          ~onShellReady=() => {
            response->Express.Response.setHeader("Content-Type", "text/html")

            response->Express.Response.setStatus(didError.contents ? 500 : 200)

            // Pipe the result from React's rendering through our response stream (to our response).
            // This only pipes the app-shell with any data that has instantly
            // loaded.
            (stream.contents->Belt.Option.getUnsafe).ReactDOMServer.pipe(
              transformAsWritable(transformOutputStream),
            )
            // Clean up when the transformation stream is closed.
            ->NodeJs.Stream.fromWritable
            ->NodeJs.Stream.onClose(cleanup)

            resolve(. ignore())
          },
          ~onShellError=err => {
            cleanup()
            reject(. err)
          },
          ~onError=err => {
            cleanup()
            didError := true
            Js.Console.error(err)
          },
          (),
        ),
      )->Some
  })
}
