module type EntryServer = module type of EntryServer
@val external import_: string => Promise.t<module(EntryServer)> = "import"

let app = Express.make()

let loadRouterManifest = () =>
  NodeJs.Fs.readFileSync("dist/client/routerManifest.json", "utf-8")->RelayRouter.Manifest.parse

switch NodeJs.isProduction {
| true => {
    open Express

    // Only enable the file server when ENABLE_FILESERVER is set.
    // We expect production deployments to have a non Node.js HTTP server serving static files.
    if NodeJs.shouldEnableFileserver {
      app->useMiddlewareAt("/assets", Express.static("dist/client/assets/"))
    }

    let manifest = loadRouterManifest()

    // Load our compiled production server entry.
    import_("./dist/server/EntryServer.js")
    ->Promise.thenResolve(entryServer => {
      module EntryServer = unpack(entryServer)

      // Production server side rendering helper.
      app->useRoute("*", (request, response) => {
        EntryServer.handleRequest(~request, ~response, ~manifest)
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
        ->ssrLoadModule("/src/EntryServer.mjs")
        ->Promise.then((entryServer: module(EntryServer)) => {
          open RelayRouter.Manifest
          module EntryServer = unpack(entryServer)

          let entryPoint = "/src/EntryClient.mjs"
          let manifest = {
            entryPoint: entryPoint,
            files: Js.Dict.fromArray([(entryPoint, {imports: [], css: [], assets: []})]),
          }

          EntryServer.handleRequest(~request, ~response, ~manifest)
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
