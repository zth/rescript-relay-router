type response

@module("@remix-run/web-fetch")
external fetchServer: (string, 'fetchOpts) => promise<response> = "fetch"

@val
external fetch: (string, 'fetchOpts) => promise<response> = "fetch"

let getChunks: (
  response,
  ~onNext: Js.Json.t => unit,
  ~onError: Js.Exn.t => unit,
  ~onComplete: unit => unit,
) => promise<unit>
