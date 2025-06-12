open RelayRouter__Types

type rawSetQueryParamsFnConfig = {
  applyQueryParams: RelayRouter__Bindings.QueryParams.t => unit,
  currentSearch: string,
  navigationMode_: setQueryParamsMode,
  removeNotControlledParams: bool,
  shallow: bool,
}

type setQueryParamsFn<'queryParams> = (
  ~setter: 'queryParams => 'queryParams,
  ~onAfterParamsSet: 'queryParams => unit=?,
  ~navigationMode_: setQueryParamsMode=?,
  ~removeNotControlledParams: bool=?,
  ~shallow: bool=?,
) => unit

type parseQueryParamsFn<'queryParams> = RelayRouter__Bindings.QueryParams.t => 'queryParams
type applyQueryParamsFn<'queryParams> = (
  RelayRouter__Bindings.QueryParams.t,
  ~newParams: 'queryParams,
) => unit

let useSetQueryParams = (
  ~parseQueryParams: parseQueryParamsFn<'queryParams>,
  ~applyQueryParams: applyQueryParamsFn<'queryParams>,
): setQueryParamsFn<'queryParams> => {
  let router = RelayRouter__Context.useRouterContext()

  let setQueryParamsFn = React.useCallback(
    ({applyQueryParams, currentSearch, navigationMode_, removeNotControlledParams, shallow}) => {
      open RelayRouter__Bindings

      let queryParams = if removeNotControlledParams {
        QueryParams.make()
      } else {
        QueryParams.parse(currentSearch)
      }

      applyQueryParams(queryParams)

      if shallow {
        router.markNextNavigationAsShallow()
      }

      switch navigationMode_ {
      | Push => router.history->RelayRouter__History.push(queryParams->QueryParams.toString)
      | Replace => router.history->RelayRouter__History.replace(queryParams->QueryParams.toString)
      }
    },
    (router, applyQueryParams),
  )

  React.useMemo(() => {
    let fn: setQueryParamsFn<'queryParams> = (
      ~setter,
      ~onAfterParamsSet=?,
      ~navigationMode_=Push,
      ~removeNotControlledParams=true,
      ~shallow=true,
    ) => {
      let {search} = router.history->RelayRouter__History.getLocation
      let newParams = search->RelayRouter__Bindings.QueryParams.parse->parseQueryParams->setter

      switch onAfterParamsSet {
      | None => ()
      | Some(onAfterParamsSet) => onAfterParamsSet(newParams)
      }

      setQueryParamsFn({
        applyQueryParams: queryParams => applyQueryParams(~newParams, queryParams),
        currentSearch: search,
        navigationMode_,
        removeNotControlledParams,
        shallow,
      })
    }

    fn
  }, (parseQueryParams, applyQueryParams, router))
}

type makeNewQueryParamsMakerFn<'queryParams> = 'queryParams => 'queryParams

type makeNewQueryParamsFn<'queryParams> = makeNewQueryParamsMakerFn<'queryParams> => string

let useMakeLinkWithPreservedPath = (
  ~parseQueryParams: parseQueryParamsFn<'queryParams>,
  ~applyQueryParams: applyQueryParamsFn<'queryParams>,
): makeNewQueryParamsFn<'queryParams> => {
  let router = RelayRouter__Context.useRouterContext()
  React.useMemo(() => {
    (makeNewQueryParams: 'queryParams => 'queryParams) => {
      let location = router.history->RelayRouter__History.getLocation
      let newQueryParams =
        location.search
        ->RelayRouter__Bindings.QueryParams.parse
        ->parseQueryParams
        ->makeNewQueryParams

      open RelayRouter__Bindings
      let queryParams = location.search->QueryParams.parse
      queryParams->applyQueryParams(~newParams=newQueryParams)
      location.pathname ++ queryParams->QueryParams.toString
    }
  }, (router, parseQueryParams, applyQueryParams))
}

type pathMatch = {params: dict<string>}

@module("./vendor/react-router.js") @return(nullable)
external matchPath: (string, string) => option<pathMatch> = "matchPath"

@module("./vendor/react-router.js") @return(nullable)
external matchPathWithOptions: ({"path": string, "end": bool}, string) => option<pathMatch> =
  "matchPath"

type prepared
external toObject: Type.Classify.object => {..} = "%identity"
external objectToPreparedArrayUnsafe: Type.Classify.object => array<prepared> = "%identity"

// This will extract all dispose functions from anything you feed it.
let extractDisposables = prepared => {
  let rec aux = (s, disposables, seen) => {
    switch Type.Classify.classify(s) {
    | Object(object) =>
      if !(seen->Set.has(s)) {
        seen->Set.add(s)
        if Array.isArray(object) {
          let array = objectToPreparedArrayUnsafe(object)
          array->Array.forEach(o => aux(o, disposables, seen))
        } else {
          let object = toObject(object)
          if (
            object->Object.hasOwnProperty("dispose") && Type.typeof(object["dispose"]) === #function
          ) {
            disposables->Array.push(object["dispose"])
          }
          object
          ->Object.keysToArray
          ->Array.forEach(key => {
            let o = object->Object.get(key)
            o->Option.forEach(o => aux(o, disposables, seen))
          })
        }
      }
    | _ => ()
    }
  }
  let disposables = []
  aux(prepared, disposables, Set.make())
  disposables
}

type requestIdleCallbackId

@val
external requestIdleCallback: (callback, option<{"timeout": int}>) => requestIdleCallbackId =
  "window.requestIdleCallback"

@val
external cancelIdleCallback: requestIdleCallbackId => unit = "window.cancelIdleCallback"

let supportsRequestIdleCallback: bool = if RelaySSRUtils.ssr {
  false
} else {
  %raw(`window != null && window.requestIdleCallback != null`)
}

let runCallback = (cb: callback, timeout) => {
  if supportsRequestIdleCallback {
    let id = requestIdleCallback(
      cb,
      switch timeout {
      | None => None
      | Some(timeout) => Some({"timeout": timeout})
      },
    )
    Some(() => cancelIdleCallback(id))
  } else {
    let id = setTimeout(cb, 1)
    Some(() => clearTimeout(id))
  }
}

let runAtPriority = (cb, ~priority) => {
  if !RelaySSRUtils.ssr {
    switch priority {
    | Low =>
      // On low priority, let the browser wait as long as needed
      runCallback(cb, None)
    | Default =>
      // On default priority, ensure loading starts within 2s
      runCallback(cb, Some(2000))
    | High =>
      // High priority means we'll run it right away
      cb()
      None
    }
  } else {
    None
  }
}

module RouterTransitionContext = {
  type transitionFn = (unit => unit) => unit

  let context = React.createContext(_cb => ())

  module Provider = {
    let make = React.Context.provider(context)
  }

  let use = (): transitionFn => React.useContext(context)
}

type rec routeKind<_> =
  | QueryParams({
      routePattern: string,
      parseQueryParams: RelayRouter__Bindings.QueryParams.t => 'queryParams,
    }): routeKind<'queryParams>
  | PathAndQueryParams({
      routePattern: string,
      parseQueryParams: RelayRouter__Bindings.QueryParams.t => 'queryParams,
    }): routeKind<('pathParams, 'queryParams)>
  | PathParams({routePattern: string}): routeKind<'pathParams>

let parseRoute:
  type params. routeKind<params> => (string, ~exact: bool=?) => option<params> =
  routeKind =>
    switch routeKind {
    | PathAndQueryParams({routePattern, parseQueryParams}) =>
      (route, ~exact=false) =>
        switch route->String.split("?") {
        | [pathName, search] =>
          matchPathWithOptions({"path": routePattern, "end": exact}, pathName)->Option.map(({
            params,
          }) => {
            let pathParams = Obj.magic(params)
            let queryParams =
              search
              ->RelayRouter__Bindings.QueryParams.parse
              ->parseQueryParams
            (pathParams, queryParams)
          })
        | _ => None
        }
    | QueryParams({routePattern, parseQueryParams}) =>
      (route, ~exact=false) =>
        switch route->String.split("?") {
        | [pathName, search] =>
          matchPathWithOptions({"path": routePattern, "end": exact}, pathName)->Option.map(_ => {
            search
            ->RelayRouter__Bindings.QueryParams.parse
            ->parseQueryParams
          })
        | _ => None
        }
    | PathParams({routePattern}) =>
      (route, ~exact=false) =>
        matchPathWithOptions({"path": routePattern, "end": exact}, route)->Option.map(({
          params,
        }) => {
          Obj.magic(params)
        })
    }
