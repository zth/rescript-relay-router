module type EntryServer = module type of EntryServer
@val external import_: string => Promise.t<module(EntryServer)> = "import"

let app = Express.make()

let getAssetForManifestEntry = (manifest, file) => {
  // We must prefix with `/` (Vite's configured root) because the manifest only contains paths relative to base.
  // TODO: This breaks if vite.base is not `/`.
  "/" ++
  manifest
  ->Js.Dict.unsafeGet(file)
  ->Js.Json.decodeObject
  ->Belt.Option.getExn
  ->Js.Dict.unsafeGet("file")
  ->Js.Json.decodeString
  ->Belt.Option.getExn
}

let rec getDirectImportsForManifestEntry = (manifest, file) => {
  manifest
  ->Js.Dict.unsafeGet(file)
  ->Js.Json.decodeObject
  ->Belt.Option.getExn
  ->Js.Dict.get("imports")
  ->Belt.Option.flatMap(Js.Json.decodeArray)
  ->Belt.Option.mapWithDefault(
    [],
    Js.Array2.map(_, import_ => import_->Js.Json.decodeString->Belt.Option.getExn),
  )
  ->Belt.List.fromArray
  ->Belt.List.map(import_ => list{
    getAssetForManifestEntry(manifest, import_),
    ...getDirectImportsForManifestEntry(manifest, import_),
  })
  ->Belt.List.flatten
}

let getProductionClientBundlesFromManifest = () => {
  // Load our client manifest so we can find our client entry file.
  let manifest =
    NodeJs.Fs.readFileSync("./dist/client/manifest.json", "utf-8")
    ->Js.Json.parseExn
    ->Js.Json.decodeObject
    ->Belt.Option.getExn

  // This will throw an exception if our manifest doesn't include an "index.html" entry.
  // That's what Vite uses for our main app entry point.
  list{
    getAssetForManifestEntry(manifest, "index.html"),
    ...getDirectImportsForManifestEntry(manifest, "index.html"),
  }
  ->Belt.List.toArray
  // Deduplicate entries
  ->Belt.Set.String.fromArray
  ->Belt.Set.String.toArray
}

switch NodeJs.isProduction {
| true => {
    open Express

    // Only enable the file server when ENABLE_FILESERVER is set.
    // We expect production deployments to have a non Node.js HTTP server serving static files.
    if NodeJs.shouldEnableFileserver {
      app->useMiddlewareAt("/assets", Express.static("dist/client/assets/"))
    }

    let bootstrapModules = getProductionClientBundlesFromManifest()

    // Load our compiled production server entry.
    import_("./dist/server/EntryServer.js")
    ->Promise.thenResolve(entryServer => {
      module EntryServer = unpack(entryServer)

      // Production server side rendering helper.
      app->useRoute("*", (request, response) => {
        EntryServer.handleRequest(~request, ~response, ~bootstrapModules)
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
          module EntryServer = unpack(entryServer)

          EntryServer.handleRequest(~request, ~response, ~bootstrapModules=["/src/EntryClient.mjs"])
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
