@live
let bootOnClient: (~rootElementId: string, ~render: React.element) => unit

@live
let setHasPreparedInitialRoutes: unit => unit

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
  RelayRouter__Types.onResponseReceivedFn,
  (
    RescriptRelay.Observable.sink<Js.Json.t>,
    RescriptRelay.Network.operation,
    Js.Json.t,
    RescriptRelay.cacheConfig,
    Js.Nullable.t<RescriptRelay.uploadables>,
  ) => option<RescriptRelay.Observable.subscription>,
) => RescriptRelay.Network.fetchFunctionObservable

@live
let ssr: bool

module AssetRegisterer: {
  type context = RelayRouter__Types.preloadAsset => unit

  @live
  let use: unit => context

  module Provider: {
    @live
    let make: React.component<{
      "children": React.element,
      "value": context,
    }>
    @live
    let makeProps: (
      ~value: context,
      ~children: React.element,
      unit,
    ) => {"children": React.element, "value": context}
  }
}
