type onQuery = (~id: string, ~response: option<JSON.t>=?, ~final: option<bool>=?) => unit
type onAssetPreload = string => unit

module Node = {
  // PreloadInsertingStream is actually a Node.js `Writable` instance.
  // However, we don't want the router to depend on a NodeJS type package.
  // TODO: Ensure user-land doesn't have to write their own typecasting to use this stream.
  type t /* = NodeJs.Writable.Stream.t */

  @new @module("./PreloadInsertingStreamNode.mjs") external make: 'a => t = "default"

  @send
  external onQuery: (t, ~id: string, ~response: option<JSON.t>=?, ~final: option<bool>=?) => unit =
    "onQuery"

  @send external onAssetPreload: (t, string) => unit = "onAssetPreload"
}
