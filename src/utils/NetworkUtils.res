@deriving(abstract) @live
type fetchOpts = {
  _method: string,
  headers: Js.Dict.t<string>,
  body: string,
}

type response

@val
external fetch: (string, fetchOpts) => Promise.t<{"json": (. unit) => Promise.t<Js.Json.t>}> =
  "fetch"

@val
external fetch2: (string, fetchOpts) => Promise.t<response> = "fetch"

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
				onError(new Error('Failed to parse part as json.'));
				break;
			}

			onNext(part.body);
    }
  }`)

  @module("meros")
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

let fetchQuery = RelaySSRUtils.makeClientFetchFunction((
  sink,
  operation,
  variables,
  _cacheConfig,
  _uploads,
) => {
  fetch2(
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

let makeServerFetchQuery = (~onResponseReceived): RescriptRelay.Network.fetchFunctionObservable => {
  RelaySSRUtils.makeServerFetchFunction(onResponseReceived, (
    sink,
    operation,
    variables,
    _cacheConfig,
    _uploads,
  ) => {
    fetch2(
      "http://localhost:4000/graphql",
      fetchOpts(
        ~_method="POST",
        ~headers=Js.Dict.fromArray([("content-type", "application/json")]),
        ~body={"query": operation.text, "variables": variables}
        ->Js.Json.stringifyAny
        ->Belt.Option.getWithDefault(""),
      ),
    )
    ->Promise.then(r => {
      Js.log(r)
      r->Meros.getChunks(
        ~onNext=(. part) => {
          sink.next(. part)
        },
        ~onError=(. err) => {
          sink.error(. err)
        },
        ~onComplete=sink.complete,
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
