@deriving(abstract) @live
type fetchOpts = {
  _method: string,
  headers: Js.Dict.t<string>,
  body: string,
}

@val
external fetch: (string, fetchOpts) => Promise.t<{"json": (. unit) => Promise.t<Js.Json.t>}> =
  "fetch"

let fetchQuery = RelaySSRUtils.makeClientFetchFunction((
  sink,
  operation,
  variables,
  _cacheConfig,
  _uploads,
) => {
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
  ->Promise.then(r => r["json"](.))
  ->Promise.thenResolve(json => {
    sink.next(. json)
    sink.complete(.)
  })
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
    Js.log("fetching op")
    Js.log(operation)
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
    ->Promise.then(r => r["json"](.))
    ->Promise.then(json => {
      sink.next(. json)
      sink.complete(.)
      Promise.resolve()
    })
    ->Promise.catch(e => {
      sink.error(. e->Obj.magic)
      Promise.resolve()
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
