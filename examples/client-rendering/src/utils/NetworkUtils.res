// This is a simple example of how one could leverage `preloadAsset` to preload
// things from the GraphQL response. This should live inside of the
// (comprehensive) example application we're going to build eventually.
let preloadFromResponse = (part: JSON.t, ~preloadAsset: RelayRouter__Types.preloadAssetFn) => {
  switch part {
  | Object(dict{"extensions": JSON.Object(dict{"preloadableImages": JSON.Array(images)})}) =>
    images->Array.forEach(item =>
      switch item {
      | String(imgUrl) =>
        preloadAsset(~priority=RelayRouter.Types.Default, RelayRouter.Types.Image({url: imgUrl}))
      | _ => ()
      }
    )
  | _ => ()
  }
}

let makeFetchQuery = (~preloadAsset): RescriptRelay.Network.fetchFunctionObservable => {
  (operation, variables, _cacheConfig, _uploads) => {
    RescriptRelay.Observable.make(sink => {
      open RelayRouter.NetworkUtils

      fetch(
        "http://0.0.0.0:4000/graphql",
        {
          "method": "POST",
          "headers": dict{"content-type": "application/json"},
          "body": {"query": operation.text, "variables": variables}
          ->JSON.stringifyAny
          ->Option.getOr(""),
        },
      )
      ->Promise.thenResolve(r => {
        r->getChunks(
          ~onNext=part => {
            part->preloadFromResponse(~preloadAsset)
            sink.next(part)
          },
          ~onError=err => {
            err->sink.error
          },
          ~onComplete=() => {
            sink.complete()
          },
        )
      })
      ->Promise.ignore

      None
    })
  }
}
