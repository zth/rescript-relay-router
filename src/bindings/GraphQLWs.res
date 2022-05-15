module Client = {
  type t

  type options = {
    url: string,
    connectionParams: option<unit => Js.Dict.t<string>>,
  }

  let makeOptions = (~url, ~connectionParams=?, ()) => {
    url: url,
    connectionParams: connectionParams,
  }

  type unsubscribeFn = unit => unit

  type subscribeOptions = {
    operationName: string,
    query: string,
    variables: Js.Json.t,
  }

  @val @module("graphql-ws") external make: options => t = "createClient"
  @send
  external subscribe: (
    t,
    subscribeOptions,
    RescriptRelay.Observable.sink<Js.Json.t>,
  ) => unsubscribeFn = "subscribe"
}
