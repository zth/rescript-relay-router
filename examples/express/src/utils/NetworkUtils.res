// This is a simple example of how one could leverage `preloadAsset` to preload
// things from the GraphQL response. This should live inside of the
// (comprehensive) example application we're going to build eventually.
let preloadFromResponse = (part: Js.Json.t, ~preloadAsset: RelayRouter__Types.preloadAssetFn) => {
  switch part->Js.Json.decodeObject {
  | None => ()
  | Some(obj) =>
    switch obj->Dict.get("extensions") {
    | None => ()
    | Some(extensions) =>
      switch extensions->Js.Json.decodeObject {
      | None => ()
      | Some(extensions) =>
        extensions
        ->Dict.get("preloadableImages")
        ->Option.map(images =>
          images
          ->Js.Json.decodeArray
          ->Option.getWithDefault([])
          ->Array.filterMap(item => item->Js.Json.decodeString)
        )
        ->Option.getWithDefault([])
        ->Array.forEach(imgUrl => {
          preloadAsset(~priority=RelayRouter.Types.Default, RelayRouter.Types.Image({url: imgUrl}))
        })
      }
    }
  }
}

// The client and server fetch query are currently copied, but one could easily
// set them up so that they use the same base, and just take whatever config
// they need.
let makeFetchQuery = (~preloadAsset) =>
  RelaySSRUtils.makeClientFetchFunction((sink, operation, variables, _cacheConfig, _uploads) => {
    open RelayRouter.NetworkUtils

    fetch(
      "http://localhost:4000/graphql",
      {
        "method": "POST",
        "headers": Js.Dict.fromArray([("content-type", "application/json")]),
        "body": {"query": operation.text, "variables": variables}
        ->Js.Json.stringifyAny
        ->Option.getWithDefault(""),
      },
    )
    ->Promise.thenResolve(r => {
      r->getChunks(
        ~onNext=part => {
          part->preloadFromResponse(~preloadAsset)
          sink.next(part)
        },
        ~onError=err => {
          sink.error(err)
        },
        ~onComplete=() => {
          sink.complete()
        },
      )
    })
    ->ignore

    None
  })

let makeServerFetchQuery = (
  ~onQuery,
  ~preloadAsset,
): RescriptRelay.Network.fetchFunctionObservable => {
  RelaySSRUtils.makeServerFetchFunction(onQuery, (
    sink,
    operation,
    variables,
    _cacheConfig,
    _uploads,
  ) => {
    open RelayRouter.NetworkUtils

    fetchServer(
      "http://localhost:4000/graphql",
      {
        "method": "POST",
        "headers": Js.Dict.fromArray([("content-type", "application/json")]),
        "body": {"query": operation.text, "variables": variables}
        ->Js.Json.stringifyAny
        ->Option.getWithDefault(""),
      },
    )
    ->Promise.thenResolve(r => {
      r->getChunks(
        ~onNext=part => {
          part->preloadFromResponse(~preloadAsset)
          sink.next(part)
        },
        ~onError=err => {
          sink.error(err)
        },
        ~onComplete=() => {
          sink.complete()
        },
      )
    })
    ->ignore

    None
  })
}
