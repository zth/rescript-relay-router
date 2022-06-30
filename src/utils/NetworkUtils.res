@deriving(abstract) @live
type fetchOpts = {
  _method: string,
  headers: Js.Dict.t<string>,
  body: string,
}

type response

@val
external fetch: (string, fetchOpts) => Promise.t<'any> = "fetch"

@module("@remix-run/web-fetch")
external fetchServer: (string, fetchOpts) => Promise.t<'any> = "fetch"

module Meros = {
  type parts

  @send
  external getPartsJson: parts => Js.Promise.t<Js.Json.t> = "json"

  let isAsyncIterable: parts => bool = %raw(`function isAsyncIterable(input) {
	return (
		typeof input === 'object' &&
		input !== null &&
		(input[Symbol.toStringTag] === 'AsyncGenerator' ||
			Symbol.asyncIterator in input)
	)
}`)

  let decodeEachChunk: (
    parts,
    (. Js.Json.t) => unit,
    (. Js.Exn.t) => unit,
  ) => Js.Promise.t<unit> = %raw(`async function(parts, onNext, onError) {
    for await (const part of parts) {
			if (!part.json) {
        // console.log("no json from part", part);
				// onError(new Error('Failed to parse part as json.'));
				break;
			}

			onNext(part.body);
    }
  }`)

  @module("meros/browser")
  external meros: response => Js.Promise.t<parts> = "meros"

  let getChunks = (response: response, ~onNext, ~onError, ~onComplete): Js.Promise.t<unit> => {
    meros(response)->Js.Promise.then_(parts => {
      if isAsyncIterable(parts) {
        parts->decodeEachChunk(onNext, onError)->Js.Promise.then_(() => {
          onComplete(.)
          Js.Promise.resolve()
        }, _)
      } else {
        try {
          parts->getPartsJson->Js.Promise.then_(json => {
            onNext(. json)
            onComplete(.)
            Js.Promise.resolve()
          }, _)
        } catch {
        | Js.Exn.Error(err) =>
          onError(. err)
          Js.Promise.resolve()
        }
      }
    }, _)
  }
}

// This is a simple example of how one could leverage `preloadAsset` to preload
// things from the GraphQL response. We should package this up in a good way
// before a proper release.
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

let makeFetchQuery = (~preloadAsset) =>
  RelaySSRUtils.makeClientFetchFunction((sink, operation, variables, _cacheConfig, _uploads) => {
    fetch(
      "http://localhost:4000/graphql",
      fetchOpts(
        ~_method="POST",
        ~headers=Js.Dict.fromArray([("content-type", "application/json")]),
        ~body={"query": operation.text, "variables": variables}
        ->Js.Json.stringifyAny
        ->Belt.Option.getWithDefault(""),
      ),
    )
    ->Promise.then(r =>
      r->Meros.getChunks(
        ~onNext=(. part) => {
          part->preloadFromResponse(~preloadAsset)
          sink.next(. part)
        },
        ~onError=(. err) => {
          sink.error(. err)
        },
        ~onComplete=sink.complete,
      )
    )
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
    fetchServer(
      "http://localhost:4000/graphql",
      fetchOpts(
        ~_method="POST",
        ~headers=Js.Dict.fromArray([("content-type", "application/json")]),
        ~body={"query": operation.text, "variables": variables}
        ->Js.Json.stringifyAny
        ->Belt.Option.getWithDefault(""),
      ),
    )
    ->Promise.thenResolve(r => {
      r->Meros.getChunks(
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

/* let subscriptionsClient = GraphQLWs.Client.make(
  GraphQLWs.Client.makeOptions(~url="ws://localhost:4000/graphql", ()),
)

let subscribeFn: RescriptRelay.Network.subscribeFn = (operation, variables, _cacheConfig) =>
  RescriptRelay.Observable.make(sink => {
    let unsubscribe = subscriptionsClient->GraphQLWs.Client.subscribe(
      {
        operationName: operation.name,
        query: operation.text,
        variables: variables,
      },
      sink,
    )

    Some({
      unsubscribe: unsubscribe,
      closed: false,
    })
  })*/
