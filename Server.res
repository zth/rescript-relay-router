@val external import_: string => Promise.t<'a> = "import"

let app = Express.make()

switch NodeJs.isProduction {
| true => {
    open Express

    // Only enable the file server when ENABLE_FILESERVER is set.
    // We expect production deployments to have a non Node.js HTTP server serving static files.
    if NodeJs.shouldEnableFileserver {
      app->useMiddlewareAt("/assets", Express.static("dist/client/assets/"))
    }

    // Load our client manifest so we can find our client entry file.
    let manifest =
      NodeJs.Fs.readFileSync("./dist/client/manifest.json", "utf-8")
      ->Js.Json.parseExn
      ->Js.Json.decodeObject
      ->Belt.Option.getExn

    // This will throw an exception if our manifest doesn't include an "index.html" entry.
    // That's what Vite uses for our main app entry point.
    // We must prefix with `/` (Vite's configured root) because the manifest only contains paths relative to base.
    // TODO: This breaks if vite.base is not `/`.
    let clientBundle =
      "/" ++
      manifest
      ->Js.Dict.get("index.html")
      ->Belt.Option.getExn
      ->Js.Json.decodeObject
      ->Belt.Option.getExn
      ->Js.Dict.unsafeGet("file")
      ->Js.Json.decodeString
      ->Belt.Option.getExn

    // TODO: Read clientBundle deps from manifest so we can also immediatly load those direct dependencies.

    let bootstrapModules = [clientBundle]

    // Load our compiled production server entry.
    import_("./dist/server/EntryServer.js")
    ->Promise.then(imported => imported["default"])
    ->Promise.thenResolve(handleRequest => {
      // Production server side rendering helper.
      app->useRoute("*", (request, response) => {
        handleRequest(~request, ~response, ~bootstrapModules)
      })

      app->listen(9999)

      Js.Console.log(`Listening on http://localhost:9999 🚀`)
    })
    ->ignore
  }

| false =>
  Vite.make(~middlewareMode=#ssr)
  ->Promise.thenResolve(vite => {
    open Express

    app->useMiddleware(vite->Vite.middlewares)

    // Development server side rendering handler
    app->useRoute("*", (request, response) => {
      // TODO: Error handling here doesn't really exist.
      open Vite

      try {
        // Load the dev server entry point through Vite within the route handler so it's automatically
        // recompiled when any of the code changes (Vite caches it for us).
        vite
        ->loadDevSsrEntryPoint("/src/EntryServer.mjs")
        ->Promise.then(imported => imported["default"])
        ->Promise.then(handleRequest => {
          handleRequest(~request, ~response, ~bootstrapModules=["/src/EntryClient.mjs"])
        })
      } catch {
      | Js.Exn.Error(err) => {
          vite->ssrFixStacktrace(err)
          Js.Console.log("[debug] got error")
          Js.Console.log(err)
          // Can't set a proper status here as we've already sent the status code
          // when we started streaming. TODO: Replace with a proper error screen or
          // similar?
          // TODO: No stream to write to here?
          // res.end(e.message);
          Js.Promise.resolve()
        }
      }
    })

    app->listen(9999)

    Js.Console.log(`Listening on http://localhost:9999 🚀`)
  })
  ->ignore
}
