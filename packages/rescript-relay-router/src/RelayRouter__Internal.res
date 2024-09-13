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

type parseQueryParamsFn<'queryParams> = string => 'queryParams
type applyQueryParamsFn<'queryParams> = (
  RelayRouter__Bindings.QueryParams.t,
  ~newParams: 'queryParams,
) => unit

let useSetQueryParams = (
  ~parseQueryParams: parseQueryParamsFn<'queryParams>,
  ~applyQueryParams: applyQueryParamsFn<'queryParams>,
): setQueryParamsFn<'queryParams> => {
  let router = RelayRouter__Context.useRouterContext()

  let setQueryParamsFn = React.useCallback3(
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
    (router, parseQueryParams, applyQueryParams),
  )

  React.useMemo3(() => {
    let fn: setQueryParamsFn<'queryParams> = (
      ~setter,
      ~onAfterParamsSet=?,
      ~navigationMode_=Push,
      ~removeNotControlledParams=true,
      ~shallow=true,
    ) => {
      let {search} = router.history->RelayRouter__History.getLocation
      let newParams = setter(search->parseQueryParams)

      switch onAfterParamsSet {
      | None => ()
      | Some(onAfterParamsSet) => onAfterParamsSet(newParams)
      }

      setQueryParamsFn({
        applyQueryParams: applyQueryParams(~newParams, ...),
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
  React.useMemo3(() => {
    (makeNewQueryParams: 'queryParams => 'queryParams) => {
      let location = router.history->RelayRouter__History.getLocation
      let newQueryParams =
        location.search
        ->parseQueryParams
        ->makeNewQueryParams

      open RelayRouter__Bindings
      let queryParams = location.search->QueryParams.parse
      queryParams->applyQueryParams(~newParams=newQueryParams)
      location.pathname ++ queryParams->QueryParams.toString
    }
  }, (router, parseQueryParams, applyQueryParams))
}

type pathMatch = {params: Js.Dict.t<string>}

@module("./vendor/react-router.js") @return(nullable)
external matchPath: (string, string) => option<pathMatch> = "matchPath"

@module("./vendor/react-router.js") @return(nullable)
external matchPathWithOptions: ({"path": string, "end": bool}, string) => option<pathMatch> =
  "matchPath"

// This will extract all dispose functions from anything you feed it.
let extractDisposables = %raw(`function extractDisposables_(s, disposables = []) {
  if (s == null) {
    return disposables;
  }

  if (Array.isArray(s)) {
    s.forEach(function (o) {
      extractDisposables_(o, disposables);
    });
    return disposables;
  } 

  if (typeof s === "object") {
    if ( 
      s.hasOwnProperty("dispose") && 
      typeof s.dispose === "function"
    ) {
      disposables.push(s.dispose);
    }

    Object.keys(s).forEach(function (key) {
      var o = s[key];
      extractDisposables_(o, disposables);
    })
  }

  return disposables;
}`)

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
