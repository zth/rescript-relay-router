type response

// TODO: Decide on whether we want to ship full type safe bindings here.
@module("@remix-run/web-fetch")
external fetch: (string, 'fetchOpts) => Promise.t<response> = "fetch"

let getChunks: (
  response,
  ~onNext: (. Js.Json.t) => unit,
  ~onError: (. Js.Exn.t) => unit,
  ~onComplete: (. unit) => unit,
) => Js.Promise.t<unit>
