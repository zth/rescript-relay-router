// TODO: Not that it matters too much, but we should find a way to ensure only a
// single map is used on the client. This one is defined here, and then there's
// another one inside of Router.make.
let preparedAssetsMap = Js.Dict.empty()

let network = RescriptRelay.Network.makeObservableBased(
  ~observableFunction=NetworkUtils.makeFetchQuery(
    ~preloadAsset=RelayRouter.Utils.AssetPreloader.clientPreloadAsset(~preparedAssetsMap),
  ),
  // ~subscriptionFunction=NetworkUtils.subscribeFn,
  (),
)

let makeEnvironmentWithNetwork = (~network, ~missingFieldHandlers=?, ()) =>
  RescriptRelay.Environment.make(
    ~network,
    ~missingFieldHandlers=?{missingFieldHandlers},
    ~store=RescriptRelay.Store.make(
      ~source=RescriptRelay.RecordSource.make(),
      ~gcReleaseBufferSize=50,
      ~queryCacheExpirationTime=6 * 60 * 60 * 1000,
      (),
    ),
    (),
  )

let environment = makeEnvironmentWithNetwork(~network, ())

@live
let makeServer = (~onResponseReceived, ~onQueryInitiated, ~preloadAsset) => {
  let network = RescriptRelay.Network.makeObservableBased(
    ~observableFunction=NetworkUtils.makeServerFetchQuery(
      ~onResponseReceived,
      ~onQueryInitiated,
      ~preloadAsset,
    ),
    (),
  )
  makeEnvironmentWithNetwork(~network, ())
}
