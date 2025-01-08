module QueryParams = {
  type t = dict<array<string>>

  let make = () => Dict.make()

  let deleteParam = (dict, key) => Dict.delete(Obj.magic(dict), key)

  let setParam = (dict, ~key, ~value) => dict->Dict.set(key, [value])
  let setParamOpt = (dict, ~key, ~value) =>
    switch value {
    | Some(value) => dict->Dict.set(key, [value])
    | None => dict->deleteParam(key)
    }

  let setParamInt = (dict, ~key, ~value) =>
    dict->setParamOpt(~key, ~value=value->Option.map(v => Int.toString(v)))

  let setParamBool = (dict, ~key, ~value) =>
    dict->setParamOpt(
      ~key,
      ~value=switch value {
      | Some(false) => Some("false")
      | Some(true) => Some("true")
      | _ => None
      },
    )

  let setParamArray = (dict, ~key, ~value) => dict->Dict.set(key, value)
  let setParamArrayOpt = (dict, ~key, ~value) =>
    switch value {
    | Some(value) => dict->Dict.set(key, value)
    | None => dict->deleteParam(key)
    }

  let printValue = value =>
    value
    ->Array.map(v => encodeURIComponent(v))
    ->Array.join(",")

  let printKeyValue = (key, value) => key ++ "=" ++ printValue(value)

  let toString = raw => {
    let parts =
      raw
      ->Dict.toArray
      ->Array.map(((key, value)) => {
        printKeyValue(key, value)
      })

    switch parts->Array.length {
    | 0 => ""
    | _ => "?" ++ parts->Array.join("&")
    }
  }

  let toStringStable = raw => {
    let parts =
      raw
      ->Dict.toArray
      ->Array.toSorted(((a, _), (b, _)) =>
        if a->String.localeCompare(b) > 0. {
          1.0
        } else {
          -1.0
        }
      )
      ->Array.map(((key, value)) => {
        printKeyValue(key, value)
      })

    switch parts->Array.length {
    | 0 => ""
    | _ => "?" ++ parts->Array.join("&")
    }
  }

  let decodeValue = value => {
    value->String.split(",")->Array.map(v => decodeURIComponent(v))
  }

  let parse = search => {
    let dict = Dict.make()

    let search = if search->String.startsWith("?") {
      search->String.sliceToEnd(~start=1)
    } else {
      search
    }

    let parts = search->String.split("&")

    parts->Array.forEach(part => {
      let keyValue = part->String.split("=")
      switch (keyValue->Array.get(0), keyValue->Array.get(1)) {
      | (Some(key), Some(value)) => dict->Dict.set(key, decodeValue(value))
      | _ => ()
      }
    })

    dict
  }

  let getParamByKey = (parsedParams, key) =>
    parsedParams->Dict.get(key)->Option.getOr([])->Array.get(0)

  let getArrayParamByKey = (parsedParams, key) => parsedParams->Dict.get(key)

  let getParamInt = (parsedParams, key) =>
    switch parsedParams->getParamByKey(key) {
    | None => None
    | Some(raw) => Int.fromString(raw)
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
  external getState: t => JSON.t = "state"
}

type streamedEntry = {
  id: string,
  response: option<JSON.t>,
  final: option<bool>,
}

module RelayReplaySubject = {
  type t

  @module("relay-runtime") @new
  external make: unit => t = "ReplaySubject"

  @send
  external complete: t => unit = "complete"

  @send
  external error: (t, Exn.t) => unit = "error"

  @send
  external next: (t, JSON.t) => unit = "next"

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
external generatePath: (string, dict<string>) => string = "generatePath"
