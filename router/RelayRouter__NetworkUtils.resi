type response

@module("@remix-run/web-fetch")
external fetchServer: (string, 'fetchOpts) => Js.Promise.t<response> = "fetch"

@val
external fetch: (string, 'fetchOpts) => Js.Promise.t<response> = "fetch"

let getChunks: (
  response,
  ~onNext: (. Js.Json.t) => unit,
  ~onError: (. Js.Exn.t) => unit,
  ~onComplete: (. unit) => unit,
) => Js.Promise.t<unit>
