module type EntryServer = module type of EntryServer
@val external import_: string => Promise.t<module(EntryServer)> = "import"

let app = Express.make()

module ViteManifest = {
  type chunk = {
    file: string,
    src: Js.Nullable.t<string>,
    isEntry: Js.Nullable.t<bool>,
    isDynamicEntry: Js.Nullable.t<bool>,
    imports: Js.Nullable.t<array<string>>,
    dynamicImports: Js.Nullable.t<array<string>>,
    css: Js.Nullable.t<array<string>>,
    assets: Js.Nullable.t<array<string>>,
  }
  type t = Js.Dict.t<chunk>
  external objToManifest: Js.Json.t => t = "%identity"
}

/**
 * Convert the Vite client manifest.json to a specialised manifest for ReScript Relay Router.
 *
 * The manifest for ReScript Relay router contains less information which makes it suitable to
 * ship to the client and is only interested in dealing with compiled assets and their hierarchies.
 */
let viteManifestToRelayRouterManifest: ViteManifest.t => RelayRouter.Manifest.t = manifest => {
  let orEmptyArray = nullableArray =>
    nullableArray->Js.Nullable.toOption->Belt.Option.getWithDefault([])
  let getChunk = Js.Dict.unsafeGet(manifest)
  let getFile = import_ => "/" ++ getChunk(import_).file
  // let getImports = import_ => getChunk(import_).imports->orEmptyArray
  // let getCss = import_ => getChunk(import_).css->orEmptyArray
  // let getAssets = import_ => getChunk(import_).assets->orEmptyArray

  manifest
  ->Js.Dict.entries
  ->Belt.Array.keepMap(((source, chunk)) => {
    open RelayRouter.Manifest
    // The isEntry or isDynamicEntry field is only ever present when it's `true`.
    switch !(chunk.isEntry->Js.Nullable.isNullable) ||
    !(chunk.isDynamicEntry->Js.Nullable.isNullable) {
    | true =>
      Some((
        source->getFile,
        {
          imports: chunk.imports->orEmptyArray->Js.Array2.map(getFile),
          css: chunk.css->orEmptyArray,
          assets: chunk.assets->orEmptyArray,
        },
      ))
    | false => None
    }
  })
  ->Js.Dict.fromArray
}

let loadRouterManifest = () => {
  // Load our client manifest so we can find our client entry file.
  let viteManifest =
    NodeJs.Fs.readFileSync("./dist/client/manifest.json", "utf-8")
    ->Js.Json.parseExn
    ->ViteManifest.objToManifest

  let entryPoint = "/" ++ (viteManifest->Js.Dict.unsafeGet("index.html")).file

  (entryPoint, viteManifest->viteManifestToRelayRouterManifest)
}

switch NodeJs.isProduction {
| true => {
    open Express

    // Only enable the file server when ENABLE_FILESERVER is set.
    // We expect production deployments to have a non Node.js HTTP server serving static files.
    if NodeJs.shouldEnableFileserver {
      app->useMiddlewareAt("/assets", Express.static("dist/client/assets/"))
    }

    let (entryPoint, manifest) = loadRouterManifest()

    // Load our compiled production server entry.
    import_("./dist/server/EntryServer.js")
    ->Promise.thenResolve(entryServer => {
      module EntryServer = unpack(entryServer)

      // Production server side rendering helper.
      app->useRoute("*", (request, response) => {
        EntryServer.handleRequest(~request, ~response, ~entryPoint, ~manifest)
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
          let manifest = Js.Dict.fromArray([(entryPoint, {imports: [], css: [], assets: []})])

          EntryServer.handleRequest(~request, ~response, ~entryPoint, ~manifest)
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
