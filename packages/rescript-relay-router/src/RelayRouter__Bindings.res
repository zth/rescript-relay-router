module QueryParams = {
  type t

  @new external make: unit => t = "URLSearchParams"
  @new external fromString: string => t = "URLSearchParams"

  @send external deleteParam: (t, string) => unit = "delete"

  @send external setParam: (t, ~key: string, ~value: 'value) => unit = "set"

  @send external append: (t, ~key: string, ~value: string) => unit = "append"

  let setParamOpt = (t, ~key, ~value) =>
    switch value {
    | Some(value) => t->setParam(~key, ~value)
    | None => t->deleteParam(key)
    }

  let setParamInt = setParamOpt

  let setParamBool = setParamOpt

  let setParamArray = (t, ~key, ~value) => {
    t->deleteParam(key)
    value->Array.forEach(value => t->append(~key, ~value))
  }
  let setParamArrayOpt = (t, ~key, ~value) =>
    switch value {
    | Some(value) => t->setParamArray(~key, ~value)
    | None => t->deleteParam(key)
    }

  @send external toString: t => string = "toString"

  @send external sort: t => unit = "sort"

  let toString = t => {
    let search = t->toString

    switch search {
    | "" => ""
    | _ => "?" ++ search
    }
  }

  let toStringStable = t => {
    t->sort
    t->toString
  }

  let decodeValue = value => {
    value->String.split(",")->Array.map(v => decodeURIComponent(v))
  }

  let parse = search => {
    if search->String.includes(",") {
      let t = make()

      let search = if search->String.startsWith("?") {
        search->String.slice(~start=1)
      } else {
        search
      }

      let parts = search->String.split("&")

      parts->Array.forEach(part => {
        let keyValue = part->String.split("=")
        switch (keyValue->Array.get(0), keyValue->Array.get(1)) {
        | (Some(key), Some(value)) => t->setParamArray(~key, ~value=decodeValue(value))
        | _ => ()
        }
      })

      t
    } else {
      fromString(search)
    }
  }

  @return(nullable) @send
  external getParamByKey: (t, string) => option<string> = "get"

  @send
  external getArrayParamByKey: (t, string) => array<string> = "getAll"
  let getArrayParamByKey = (t, key) =>
    switch t->getArrayParamByKey(key) {
    | [] => None
    | array => Some(array)
    }

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

@module("./vendor/react-router.js")
external generatePath: (string, dict<string>) => string = "generatePath"
