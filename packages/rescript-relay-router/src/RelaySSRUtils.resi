@live
let bootOnClient: (~render: unit => React.element) => unit

@live
let makeClientFetchFunction: (
  (
    RescriptRelay.Observable.sink<JSON.t>,
    RescriptRelay.Network.operation,
    JSON.t,
    RescriptRelay.cacheConfig,
    Nullable.t<RescriptRelay.uploadables>,
  ) => option<RescriptRelay.Observable.subscription>
) => RescriptRelay.Network.fetchFunctionObservable

@live
let makeServerFetchFunction: (
  RelayRouter__PreloadInsertingStream.onQuery,
  (
    RescriptRelay.Observable.sink<JSON.t>,
    RescriptRelay.Network.operation,
    JSON.t,
    RescriptRelay.cacheConfig,
    Nullable.t<RescriptRelay.uploadables>,
  ) => option<RescriptRelay.Observable.subscription>,
) => RescriptRelay.Network.fetchFunctionObservable

@live @inline @val
external ssr: bool = "import.meta.env.SSR"
