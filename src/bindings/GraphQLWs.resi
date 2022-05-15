module Client: {
  type t

  type options = {
    url: string,
    connectionParams: option<unit => Js.Dict.t<string>>,
  }

  let makeOptions: (~url: string, ~connectionParams: unit => Js.Dict.t<string>=?, unit) => options

  type unsubscribeFn = unit => unit

  type subscribeOptions = {
    operationName: string,
    query: string,
    variables: Js.Json.t,
  }

  let make: options => t

  let subscribe: (t, subscribeOptions, RescriptRelay.Observable.sink<Js.Json.t>) => unsubscribeFn
}
