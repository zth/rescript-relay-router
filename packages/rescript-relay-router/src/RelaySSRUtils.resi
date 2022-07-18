@live
let bootOnClient: (~render: unit => React.element) => unit

@live
let makeClientFetchFunction: (
  (
    RescriptRelay.Observable.sink<Js.Json.t>,
    RescriptRelay.Network.operation,
    Js.Json.t,
    RescriptRelay.cacheConfig,
    Js.Nullable.t<RescriptRelay.uploadables>,
  ) => option<RescriptRelay.Observable.subscription>
) => RescriptRelay.Network.fetchFunctionObservable

@live
let makeServerFetchFunction: (
  RelayRouter__PreloadInsertingStream.onQuery,
  (
    RescriptRelay.Observable.sink<Js.Json.t>,
    RescriptRelay.Network.operation,
    Js.Json.t,
    RescriptRelay.cacheConfig,
    Js.Nullable.t<RescriptRelay.uploadables>,
  ) => option<RescriptRelay.Observable.subscription>,
) => RescriptRelay.Network.fetchFunctionObservable

@live @inline @val
external ssr: bool = "import.meta.env.SSR"
