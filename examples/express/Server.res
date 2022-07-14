module type EntryServer = module type of EntryServer
@val external import_: string => Promise.t<module(EntryServer)> = "import"

let app = Express.make()

/**
 * The ReScript Relay Router client manifest.
 *
 * The manifest keeps track of client assets and their dependencies,
 * this allows it to be used for preloading.
 *
 * It only contains entry points which is what would be loaded at the
 * start of a user action (i.e. a navigation) and only provides information
 * about the hierarchy of compiled assets.
 */
module Manifest = {
  type asset = {
    imports: array<string>,
    css: array<string>,
    assets: array<string>,
  }
  type t = Js.Dict.t<asset>
}
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
let viteManifestToRelayRouterManifest: ViteManifest.t => Manifest.t = manifest => {
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
    open Manifest
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
    // TODO: We need some way to also preload the entrypoint CSS and assets for this initial router load.
    // Maybe using bootstrapModules with React is not the way to go but we should just preloadEmit our entryPoint.
    let bootstrapModules =
      [entryPoint]->Js.Array2.concat((manifest->Js.Dict.unsafeGet(entryPoint)).imports)

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
