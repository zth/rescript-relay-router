@scope("process.env") @val external nodeEnv : Js.Nullable.t<string> = "NODE_ENV"
let isProduction = nodeEnv->Js.Nullable.toOption->Belt.Option.getWithDefault("development") === "production"

@scope("process.env") @val external enableFileserver : Js.Nullable.t<string> = "ENABLE_FILESERVER"
let shouldEnableFileserver = enableFileserver->Js.Nullable.toOption->Belt.Option.getWithDefault("false") === "true"

module Fs = {
  module Stats = {
    type t

    @send external isDirectory: t => bool = "isDirectory"
  }

  @module("fs") external readdirSync : string => array<string> = "readdirSync"
  @module("fs") external readFileSync : (string, string) => string = "readFileSync"
}

module Path = {
  type t = {
  dir: string,
  root: string,
  base: string,
  name: string,
  ext: string,
}

  @module("path") @variadic external join: array<string> => string = "join"
  @module("path") external parse : string => t = "parse"
}

module Stream = {
  type t

  @send external onClose : (t, string, unit => unit) => unit = "addListener"
  let onClose = (stream, callback) => onClose(stream, "close", callback)

  @send external onFinish : (t, string, unit => unit) => unit = "addListener"
  let onFinish = (stream, callback) => onFinish(stream, "finish", callback)

  @send external end : t => unit = "end"

  module Writable = {
    type t
  }

  module PassThrough = {
    type t

    @module("stream") @new
    external make : unit => t = "PassThrough"

    external asWritable : t => Writable.t = "%identity"
  }

  external fromWritable : Writable.t => t = "%identity"
  external fromPassThrough : PassThrough.t => t = "%identity"
}
