@module("fs") external readFileSync: (string, string) => string = "readFileSync"
@module("fs") external writeFileSync: (string, string, string) => unit = "writeFileSync"

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

  {
    entryPoint: "/" ++ (manifest->Js.Dict.unsafeGet("index.html")).file,
    files: manifest
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
    ->Js.Dict.fromArray,
  }
}

/**
 * Load our client manifest.
 */
let loadViteManifest = path => {
  readFileSync(path, "utf-8")->Js.Json.parseExn->ViteManifest.objToManifest
}

let writeRouterManifest = (path, manifest: RelayRouter.Manifest.t) => {
  manifest->RelayRouter.Manifest.stringifyWithSpace(_, 2)->(writeFileSync(path, _, "utf-8"))
}

let transformManifest = (inPath, outPath) => {
  // Load our client manifest.
  let viteManifest = loadViteManifest(inPath)
  let routerManifest = viteManifestToRelayRouterManifest(viteManifest)
  writeRouterManifest(outPath, routerManifest)
}
