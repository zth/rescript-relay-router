@live
type fetchConfig = {
  @as("method")
  _method: string,
  headers: Js.Dict.t<string>,
  body: string,
  onNext: Js.Json.t => unit,
  onError: Js.Exn.t => unit,
  onComplete: unit => unit,
  credentials: [#"same-origin"],
}

@module("fetch-multipart-graphql")
external fetch: (string, fetchConfig) => unit = "default"
