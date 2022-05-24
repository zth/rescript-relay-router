let network = RescriptRelay.Network.makeObservableBased(
  ~observableFunction=NetworkUtils.fetchQuery,
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
let makeServer = (~onResponseReceived, ~onQueryInitiated) => {
  let network = RescriptRelay.Network.makeObservableBased(
    ~observableFunction=NetworkUtils.makeServerFetchQuery(~onResponseReceived, ~onQueryInitiated),
    (),
  )
  makeEnvironmentWithNetwork(~network, ())
}
