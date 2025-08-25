@module("fs") external readFileSync: (string, string) => string = "readFileSync"
@module("fs")
external writeFileSync: (~path: string, string, ~encoding: string) => unit = "writeFileSync"

module ViteManifest = {
  type chunk = {
    file: string,
    src: Nullable.t<string>,
    isEntry: Nullable.t<bool>,
    isDynamicEntry: Nullable.t<bool>,
    imports: Nullable.t<array<string>>,
    dynamicImports: Nullable.t<array<string>>,
    css: Nullable.t<array<string>>,
    assets: Nullable.t<array<string>>,
  }
  type t = dict<chunk>
  external objToManifest: JSON.t => t = "%identity"
}

/**
 * Convert the Vite client manifest.json to a specialised manifest for ReScript Relay Router.
 *
 * The manifest for ReScript Relay router contains less information which makes it suitable to
 * ship to the client and is only interested in dealing with compiled assets and their hierarchies.
 */
let viteManifestToRelayRouterManifest: ViteManifest.t => RelayRouter.Manifest.t = manifest => {
  let orEmptyArray = nullableArray =>
    switch nullableArray {
    | Nullable.Null | Undefined => []
    | Value(v) => v
    }
  let getChunk = key => Dict.getUnsafe(manifest, key)
  let getFile = import_ => "/" ++ getChunk(import_).file
  // let getImports = import_ => getChunk(import_).imports->orEmptyArray
  // let getCss = import_ => getChunk(import_).css->orEmptyArray
  // let getAssets = import_ => getChunk(import_).assets->orEmptyArray

  {
    entryPoint: "/" ++ (manifest->Dict.getUnsafe("index.html")).file,
    files: manifest
    ->Dict.toArray
    ->Array.filterMap(((source, chunk)) => {
      open RelayRouter.Manifest
      // The isEntry or isDynamicEntry field is only ever present when it's `true`.
      switch (chunk.isEntry, chunk.isDynamicEntry) {
      | (Value(_), _) | (_, Value(_)) =>
        Some((
          source->getFile,
          {
            imports: chunk.imports->orEmptyArray->Array.map(getFile),
            css: chunk.css->orEmptyArray,
            assets: chunk.assets->orEmptyArray,
          },
        ))
      | _ => None
      }
    })
    ->Dict.fromArray,
  }
}

/**
 * Load our client manifest.
 */
let loadViteManifest = path => {
  readFileSync(path, "utf-8")->JSON.parseExn->ViteManifest.objToManifest
}

let writeRouterManifest = (path, manifest: RelayRouter.Manifest.t) => {
  manifest->RelayRouter.Manifest.stringify(~space=2)->writeFileSync(~path, ~encoding="utf-8")
}

let transformManifest = (inPath, outPath) => {
  // Load our client manifest.
  let viteManifest = loadViteManifest(inPath)
  let routerManifest = viteManifestToRelayRouterManifest(viteManifest)
  writeRouterManifest(outPath, routerManifest)
}
