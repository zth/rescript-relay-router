open RescriptRelayRouterCli__Types

module Chokidar = {
  type t

  module Watcher = {
    type t

    @send
    external onChange: (t, @as(json`"change"`) _, string => unit) => t = "on"

    @send
    external onUnlink: (t, @as(json`"unlink"`) _, string => unit) => t = "on"

    @send
    external close: t => Js.Promise.t<unit> = "close"
  }

  @module("chokidar") @val
  external watcher: t = "default"

  @send
  external watch: (t, string) => Watcher.t = "watch"
}

module Path = {
  @module("path") @variadic
  external join: array<string> => string = "join"

  @module("path") @variadic
  external resolve: array<string> => string = "resolve"

  @module("path")
  external dirname: string => string = "dirname"

  @module("path")
  external basename: string => string = "basename"

  @module("path")
  external extname: string => string = "extname"
}

module Node = {
  @val
  external dirname: string = "__dirname"
}

module Process = {
  @scope("process") @val
  external cwd: unit => string = "cwd"

  @scope("process") @val
  external exit: int => unit = "exit"
}

module Glob = {
  @deriving(abstract) @live
  type opts = {
    @optional
    dot: bool,
    @optional
    cwd: string,
  }

  @live
  type glob = {sync: (array<string>, opts) => array<string>}

  @module("fast-glob")
  external glob: glob = "default"
}

module Hash = {
  type sha1

  @module("crypto")
  external createSha1Hash: (@as(json`"sha1"`) _, unit) => sha1 = "createHash"

  @send
  external update: (sha1, string) => sha1 = "update"

  @send
  external digestBase64: (sha1, @as(json`"base64"`) _) => string = "digest"

  let make = str => createSha1Hash()->update(str)->digestBase64
}

module Fs = {
  @module("fs")
  external readFileSync: (string, @as(json`"utf-8"`) _) => string = "readFileSync"

  @module("fs")
  external writeFileSync: (string, string) => unit = "writeFileSync"

  @module("fs")
  external unlinkSync: string => unit = "unlinkSync"

  @module("fs")
  external mkdirSync: string => unit = "mkdirSync"

  @module("fs")
  external mkdirRecursiveSync: (string, @as(json`{"recursive":true}`) _) => unit = "mkdirSync"

  @module("fs")
  external existsSync: string => bool = "existsSync"

  let writeFileIfChanged = (path, content) => {
    if existsSync(path) {
      let existingFileContent = readFileSync(path)
      if Hash.make(existingFileContent) != Hash.make(content) {
        writeFileSync(path, content)
      }
    } else {
      writeFileSync(path, content)
    }
  }
}

module URL = {
  type t

  @new
  external make: string => t = "URL"

  @get
  external getPathname: t => string = "pathname"

  @get
  external getSearch: t => option<string> = "search"

  @get
  external getHash: t => string = "hash"

  @get
  external getState: t => Js.Json.t = "state"
}

module CosmiConfig = {
  type t

  type config = Js.Dict.t<string>

  @live
  type result = {
    config: option<config>,
    filepath: string,
  }

  @module("cosmiconfig")
  external make: (@as(json`"rescriptRelayRouter"`) _, unit) => t = "cosmiconfigSync"

  @send @return(nullable)
  external search: t => option<result> = "search"
}

module FuzzySearch = {
  @module("fast-fuzzy")
  external search: (string, array<string>) => array<string> = "search"
}

module LinesAndColumns = {
  type t

  @module("lines-and-columns") @new
  external make: string => t = "LinesAndColumns"

  @send
  external locationForOffset: (t, int) => loc = "locationForIndex"

  @send
  external offsetForLocation: (t, loc) => int = "indexForLocation"
}
