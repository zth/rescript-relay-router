// This is a simple example of how one could leverage `preloadAsset` to preload
// things from the GraphQL response. This should live inside of the
// (comprehensive) example application we're going to build eventually.
let preloadFromResponse = (part: Js.Json.t, ~preloadAsset) => {
  switch part->Js.Json.decodeObject {
  | None => ()
  | Some(obj) =>
    switch obj->Js.Dict.get("extensions") {
    | None => ()
    | Some(extensions) =>
      switch extensions->Js.Json.decodeObject {
      | None => ()
      | Some(extensions) =>
        extensions
        ->Js.Dict.get("preloadableImages")
        ->Belt.Option.map(images =>
          images
          ->Js.Json.decodeArray
          ->Belt.Option.getWithDefault([])
          ->Belt.Array.keepMap(item => item->Js.Json.decodeString)
        )
        ->Belt.Option.getWithDefault([])
        ->Belt.Array.forEach(imgUrl => {
          preloadAsset(RelayRouter.Types.Image({url: imgUrl}), ~priority=RelayRouter.Types.Default)
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
        ->Belt.Option.getWithDefault(""),
      },
    )
    ->Promise.thenResolve(r => {
      r->getChunks(
        ~onNext=(. part) => {
          part->preloadFromResponse(~preloadAsset)
          sink.next(. part)
        },
        ~onError=(. err) => {
          sink.error(. err)
        },
        ~onComplete=(. ()) => {
          sink.complete(.)
        },
      )
    })
    ->ignore

    None
  })

let makeServerFetchQuery = (
  ~onResponseReceived,
  ~onQueryInitiated,
  ~preloadAsset,
): RescriptRelay.Network.fetchFunctionObservable => {
  RelaySSRUtils.makeServerFetchFunction(onResponseReceived, onQueryInitiated, (
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
        ->Belt.Option.getWithDefault(""),
      },
    )
    ->Promise.thenResolve(r => {
      r->getChunks(
        ~onNext=(. part) => {
          part->preloadFromResponse(~preloadAsset)
          sink.next(. part)
        },
        ~onError=(. err) => {
          sink.error(. err)
        },
        ~onComplete=(. ()) => {
          sink.complete(.)
        },
      )
    })
    ->ignore

    None
  })
}
