// TODO: Move this into the router.
module PreloadInsertingStream = {
  // TODO: This can also be e.g. a CloudFlare writable stream.
  type t = NodeJs.Stream.Writable.t

  @new @module("../PreloadInsertingStream.mjs") external make: t => t = "default"

  @send
  external onQuery: (t, ~id: string, ~response: option<'a>=?, ~final: option<bool>=?) => unit =
    "onQuery"
  @send external onAssetPreload: (t, string) => unit = "onAssetPreload"
}

// TODO: Remove this if the TODO around line 70 is accepted.
// Otherwise move this into NodeJS bindings.
@send external writeToStream: (NodeJs.Stream.Writable.t, string) => unit = "write"

@live
let default = (~request, ~response, ~clientScripts) => {
  // TODO: request should be transformed from Express to native Request and the url should be retrieved from there.
  let initialUrl = request->Express.Request.originalUrl

  // Create our transform stream that will write assets that are loaded during rendering
  // into the stream. The output of this transformed stream is actually written to our
  // response.
  let transformOutputStream = PreloadInsertingStream.make(response->Express.Response.asWritable)

  // On finish end our response stream to complete the response.
  transformOutputStream
  ->NodeJs.Stream.fromWritable
  ->NodeJs.Stream.onFinish(() =>
    response->Express.Response.asWritable->NodeJs.Stream.fromWritable->NodeJs.Stream.end
  )

  // TODO: A default version of this should be provided by us/the router/the
  // framework, or in some way be made opaque to the dev in the default case.
  let preloadAsset: RelayRouter.Types.preloadAssetFn = (asset, ~priority as _) =>
    switch asset {
    // TODO: If multiple lazy components are in the same chunk then this may load the same asset multiple times.
    | Component({chunk}) =>
      transformOutputStream->PreloadInsertingStream.onAssetPreload(j`<script type="module" src="$chunk" async></script>`)
    | Image({url}) =>
      transformOutputStream->PreloadInsertingStream.onAssetPreload(j`<link rel="preload" as="image" href="$url">`)
    }

  // TODO: Fix the RelayEnv.makeServer types so the extra function here isn't needed.
  let environment = RelayEnv.makeServer(
    ~onResponseReceived=(~queryId, ~response, ~final) =>
      transformOutputStream->PreloadInsertingStream.onQuery(
        ~id=queryId,
        ~response=Some(response),
        ~final=Some(final),
      ),
    ~onQueryInitiated=(~queryId) =>
      transformOutputStream->PreloadInsertingStream.onQuery(
        ~id=queryId,
        ~response=None,
        ~final=None,
      ),
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
        <Main environment routerContext />,
        ReactDOMServer.renderToPipeableStreamOptions(
          // This renders as React is ready to start hydrating, and ensures that
          // if the client side bundle has already been downloaded, it starts
          // hydrating right away. If not, it lets the client bundle know that
          // React is ready to hydrate, and the client bundle starts hydration
          // as soon as it loads.
          ~bootstrapScriptContent="window.__READY_TO_BOOT ? window.__BOOT() : (window.__READY_TO_BOOT = true)",
          ~onShellReady=() => {
            response->Express.Response.setHeader("Content-Type", "text/html")

            response->Express.Response.setStatus(didError.contents ? 500 : 200)

            // We write the top of the HTML document to the express stream directly.
            // Writing this to our transformOutputStream would cause any assets that
            // were used to render the app shell to be inserted before the top of our
            // document which would cause browsers to ignore our doctype.
            //
            // The previously used solution to this was to write the head of the document with
            // response code and headers before we even began rendering. However, this prevents
            // any change to response code and also makes it invalid to provide an alternative HTML
            // string in onShellError (which the examples recommend).
            //
            // TODO: My proposal is to follow the demo linked in https://github.com/reactwg/react-18/discussions/22
            // under Recommended API: renderToPipeableStream (demo at https://codesandbox.io/s/kind-sammet-j56ro?file=/server/render.js:1054-1614)
            //
            // This would move the HTML rendering itself into the React applicaton tree (with an HTML component)
            // and remove this write line completely.
            //
            // This may feel slower but actually provides the application with the most control!
            // In case you want an "sent doctype instantly" experience you would simply put the suspense boundary
            // at the top of your application (that would be equally fast to what we did in the previous solution).
            // However, if you want to load some initial data for your <head> you could
            // put your suspense boundary lower in the tree and force that data to be loaded before we start sending
            // any data. So the application has complete control on how soon it wants to send anything to the stream
            // (instantly, or after an arbitrary amount of loaded data).
            //
            // The only open challenge would be either adding a "devScripts" variable to our handler server entry
            // that will be passed to head, or transforming Vite's output to something that can be passed to React's
            // script loaders. My current code has an optional `head` but it feels like that shouldn't be in Server.res
            // because it's only used there in development.
            let clientScriptsString = clientScripts->Js.Array2.joinWith("")
            response
            ->Express.Response.asWritable
            ->writeToStream(
              `<!DOCTYPE html><html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta
      name="viewport"
      content="width=device-width, initial-scale=1, shrink-to-fit=no"
    />
    <meta name="theme-color" content="#043062" />
    <title>Example Express App</title>
    <link
      href="https://fonts.googleapis.com/css2?family=Barlow:wght@400;700&display=swap"
      rel="stylesheet"
    />
  </head>
  <body class="bg-gray-50 font-sans leading-normal tracking-normal">
    ${clientScriptsString}
    <div id="root">`,
            )

            // Pipe the result from React's rendering through our response stream (to our response).
            // This only pipes the app-shell with any data that has instantly
            // loaded.
            (stream.contents->Belt.Option.getUnsafe).ReactDOMServer.pipe(transformOutputStream)
            // Clean up when the transformation stream is closed.
            ->NodeJs.Stream.fromWritable
            ->NodeJs.Stream.onClose(cleanup)

            // We can now write the end of our page safely to our transform stream (since it's okay if)
            // it writes any assets that have been added since our pipe completed.
            // Any other script assets would be added after `</html>` which is technically
            // illegal but also accepted by all browsers and causes a complete document to be present sooner.
            transformOutputStream->writeToStream("</div></body></html>")

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
