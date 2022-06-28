@val external import_: string => Promise.t<'a> = "import"

let app = Express.make()

switch (NodeJs.isProduction) {
  // In production we do some preparation outside of the request handler.
  | true => {
    open Express

    // Only enable the file server when ENABLE_FILESERVER is set.
    // We expect production deployments to have a non Node.js HTTP server serving static files.
    if (NodeJs.shouldEnableFileserver) {
      app->useMiddlewareAt("/assets", Express.static("dist/client/assets/"))
    }

    // Load our client manifest so we can find our client entry file.
    let manifest = NodeJs.Fs.readFileSync("./dist/client/manifest.json", "utf-8")
      ->Js.Json.parseExn
      ->Js.Json.decodeObject
      ->Belt.Option.getExn

    // This will throw an exception if our manifest doesn't include an "index.html" entry.
    // That's what Vite uses for our main app entry point.
    // We must prefix with `/` (Vite's configured root) because the manifest only contains paths relative to base.
    // TODO: This breaks if vite.base is not `/`.
    let clientBundle = "/" ++ manifest->Js.Dict.get("index.html")
      ->Belt.Option.getExn
      ->Js.Json.decodeObject
      ->Belt.Option.getExn
      ->Js.Dict.unsafeGet("file")
      ->Js.Json.decodeString
      ->Belt.Option.getExn

    // TODO: Read clientBundle deps from manifest so we can also immediatly load those direct dependencies.

    // Load our compiled production server entry.
    import_("./dist/server/EntryServer.js")
      ->Promise.then(imported => imported["default"])
      ->Promise.thenResolve(handleRequest => {

        // Production server side rendering helper.
        app->useRoute("*", (request, response) => {
          handleRequest(~request, ~response, ~clientScripts=[j`<script type="module" src="$clientBundle" async></script>`])
        })

        app->listen(9999)

        Js.Console.log(`Listening on http://localhost:9999 🚀`)
      })
      ->ignore
  }
  // Only in development do we configure Vite and set up a development server.
  | false => {
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
              let entryPointPromise =  vite->loadDevSsrEntryPoint("/src/EntryServer.mjs")->Promise.then(imported => imported["default"])
              // Create a transform on an empty piece of HTML to find the HMR scripts Vite requires.
              let htmlTransformPromise = vite->transformIndexHtml(
                request->Express.Request.originalUrl,
                "<html><head></head><body></body></html>"
              )

              (entryPointPromise, htmlTransformPromise)
                ->Promise.all2
                ->Promise.then(((handleRequest, template)) => {
                  let hmrScripts = template
                    ->Js.String2.match_(%re("/<head>(.+?)<\/head>/s"))
                    ->Belt.Option.getUnsafe
                    ->Belt.Array.getUnsafe(1)
                    // Fix React Refresh for async scripts.
                    // https://github.com/vitejs/vite/issues/6759
                    ->Js.String2.replaceByRe(%re(`/>(\s*?import[\s\w]+?['"]\/@react-refresh)/`), ` async="">$1`)

                  handleRequest(~request, ~response, ~clientScripts=[hmrScripts, j`<script type="module" src="/src/EntryClient.mjs" async></script>`])
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
                Js.Promise.resolve(())
              }
            }
          })

          app->listen(9999)

          Js.Console.log(`Listening on http://localhost:9999 🚀`)
        })
        ->ignore
  }

}
