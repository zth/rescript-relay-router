module QueryParams: {
  type t

  let make: unit => t

  @live
  let setParam: (t, ~key: string, ~value: string) => unit

  @live
  let setParamOpt: (t, ~key: string, ~value: option<string>) => unit

  @live
  let setParamArray: (t, ~key: string, ~value: array<string>) => unit

  @live
  let setParamArrayOpt: (t, ~key: string, ~value: option<array<string>>) => unit

  @live
  let setParamInt: (t, ~key: string, ~value: option<int>) => unit

  @live
  let setParamBool: (t, ~key: string, ~value: option<bool>) => unit

  @live
  let deleteParam: (t, string) => unit

  @live
  let toString: t => string

  @live
  let toStringStable: t => string

  @live
  let parse: string => t

  @live
  let getParamByKey: (t, string) => option<string>

  @live
  let getArrayParamByKey: (t, string) => option<array<string>>

  @live
  let getParamInt: (t, string) => option<int>

  @live
  let getParamBool: (t, string) => option<bool>
}

module URL: {
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

type streamedEntry = {
  id: string,
  response: option<Js.Json.t>,
  final: option<bool>,
}

module RelayReplaySubject: {
  type t

  @module("relay-runtime") @new
  external make: unit => t = "ReplaySubject"

  @send
  external complete: t => unit = "complete"

  @send
  external error: (t, Js.Exn.t) => unit = "error"

  @send
  external next: (t, Js.Json.t) => unit = "next"

  @send
  external subscribe: (
    t,
    RescriptRelay.Observable.observer<'response>,
  ) => RescriptRelay.Observable.subscription = "subscribe"

  @send
  external unsubscribe: t => unit = "unsubscribe"

  @send
  external getObserverCount: t => int = "getObserverCount"

  let applyPayload: (t, streamedEntry) => unit
}
