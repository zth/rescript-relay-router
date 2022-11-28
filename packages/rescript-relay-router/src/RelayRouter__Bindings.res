module QueryParams = {
  type t = Js.Dict.t<array<string>>

  let make = () => Js.Dict.empty()

  let deleteParam = (dict, key) => Js.Dict.unsafeDeleteKey(. Obj.magic(dict), key)

  let setParam = (dict, ~key, ~value) => dict->Js.Dict.set(key, [value])
  let setParamOpt = (dict, ~key, ~value) =>
    switch value {
    | Some(value) => dict->Js.Dict.set(key, [value])
    | None => dict->deleteParam(key)
    }

  let setParamInt = (dict, ~key, ~value) =>
    dict->setParamOpt(~key, ~value=value->Belt.Option.map(v => Belt.Int.toString(v)))

  let setParamBool = (dict, ~key, ~value) =>
    dict->setParamOpt(
      ~key,
      ~value=switch value {
      | Some(false) => Some("false")
      | Some(true) => Some("true")
      | _ => None
      },
    )

  let setParamArray = (dict, ~key, ~value) => dict->Js.Dict.set(key, value)
  let setParamArrayOpt = (dict, ~key, ~value) =>
    switch value {
    | Some(value) => dict->Js.Dict.set(key, value)
    | None => dict->deleteParam(key)
    }

  let printValue = value =>
    value
    ->Js.Array2.map(v => Js.Global.encodeURIComponent(v->Js.String2.trim))
    ->Js.Array2.joinWith(",")

  let printKeyValue = (key, value) => key ++ "=" ++ printValue(value)

  let toString = raw => {
    let parts =
      raw
      ->Js.Dict.entries
      ->Js.Array2.map(((key, value)) => {
        printKeyValue(key, value)
      })

    switch parts->Js.Array2.length {
    | 0 => ""
    | _ => "?" ++ parts->Js.Array2.joinWith("&")
    }
  }

  let toStringStable = raw => {
    let parts =
      raw
      ->Js.Dict.entries
      ->Belt.SortArray.stableSortBy(((a, _), (b, _)) =>
        if a->Js.String2.localeCompare(b) > 0. {
          1
        } else {
          -1
        }
      )
      ->Js.Array2.map(((key, value)) => {
        printKeyValue(key, value)
      })

    switch parts->Js.Array2.length {
    | 0 => ""
    | _ => "?" ++ parts->Js.Array2.joinWith("&")
    }
  }

  let decodeValue = value => {
    value->Js.String2.split(",")->Js.Array2.map(v => Js.Global.decodeURIComponent(v))
  }

  let parse = search => {
    let dict = Js.Dict.empty()

    let search = if search->Js.String2.startsWith("?") {
      search->Js.String2.sliceToEnd(~from=1)
    } else {
      search
    }

    let parts = search->Js.String2.split("&")

    parts->Js.Array2.forEach(part => {
      let keyValue = part->Js.String2.split("=")
      switch (keyValue->Belt.Array.get(0), keyValue->Belt.Array.get(1)) {
      | (Some(key), Some(value)) => dict->Js.Dict.set(key, decodeValue(value))
      | _ => ()
      }
    })

    dict
  }

  let getParamByKey = (parsedParams, key) =>
    parsedParams->Js.Dict.get(key)->Belt.Option.getWithDefault([])->Belt.Array.get(0)

  let getArrayParamByKey = (parsedParams, key) => parsedParams->Js.Dict.get(key)

  let getParamInt = (parsedParams, key) =>
    switch parsedParams->getParamByKey(key) {
    | None => None
    | Some(raw) => Belt.Int.fromString(raw)
    }

  let getParamBool = (parsedParams, key) =>
    switch parsedParams->getParamByKey(key) {
    | Some("true") => Some(true)
    | Some("false") => Some(false)
    | _ => None
    }
}

module URL = {
  type t

  @new
  external make: string => t = "URL"

  @get
  external getPathname: t => string = "pathname"

  @get
  external getSearch: t => option<string> = "search"

  @get
  external getHash: t => string = "hash"

  @get
  external getState: t => Js.Json.t = "state"
}

type streamedEntry = {
  id: string,
  response: option<Js.Json.t>,
  final: option<bool>,
}

module RelayReplaySubject = {
  type t

  @module("relay-runtime") @new
  external make: unit => t = "ReplaySubject"

  @send
  external complete: t => unit = "complete"

  @send
  external error: (t, Js.Exn.t) => unit = "error"

  @send
  external next: (t, Js.Json.t) => unit = "next"

  @send
  external subscribe: (
    t,
    RescriptRelay.Observable.observer<'response>,
  ) => RescriptRelay.Observable.subscription = "subscribe"

  @send
  external unsubscribe: t => unit = "unsubscribe"

  @send
  external getObserverCount: t => int = "getObserverCount"

  let applyPayload = (t, entry: streamedEntry) => {
    switch entry {
    | {final: Some(final), response: Some(response)} =>
      t->next(response)
      if final {
        complete(t)
      }
    | _ => ()
    }
  }
}

@module("./vendor/react-router.js")
external generatePath: (string, Js.Dict.t<string>) => string = "generatePath"
