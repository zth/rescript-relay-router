type response

@module("@remix-run/web-fetch")
external fetchServer: (string, 'fetchOpts) => promise<response> = "fetch"

@val
external fetch: (string, 'fetchOpts) => promise<response> = "fetch"

let getChunks: (
  response,
  ~onNext: JSON.t => unit,
  ~onError: Exn.t => unit,
  ~onComplete: unit => unit,
) => promise<unit>
