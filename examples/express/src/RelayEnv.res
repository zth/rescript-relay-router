let preparedAssetsMap = Dict.empty()

let network = RescriptRelay.Network.makeObservableBased(
  ~observableFunction=NetworkUtils.makeFetchQuery(
    ~preloadAsset=RelayRouter.AssetPreloader.makeClientAssetPreloader(preparedAssetsMap),
  ),
)

let makeEnvironmentWithNetwork = (~network, ~missingFieldHandlers=?) =>
  RescriptRelay.Environment.make(
    ~network,
    ~missingFieldHandlers=?{missingFieldHandlers},
    ~store=RescriptRelay.Store.make(
      ~source=RescriptRelay.RecordSource.make(),
      ~gcReleaseBufferSize=50,
      ~queryCacheExpirationTime=6 * 60 * 60 * 1000,
    ),
  )

let environment = makeEnvironmentWithNetwork(~network)

@live
let makeServer = (~onQuery, ~preloadAsset) => {
  let network = RescriptRelay.Network.makeObservableBased(
    ~observableFunction=NetworkUtils.makeServerFetchQuery(~onQuery, ~preloadAsset),
  )
  makeEnvironmentWithNetwork(~network)
}
