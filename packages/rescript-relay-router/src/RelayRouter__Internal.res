open RelayRouter__Types

let setQueryParams = (queryParams, mode, history) => {
  open RelayRouter__Bindings

  switch mode {
  | Push => history->RelayRouter__History.push(queryParams->QueryParams.toString)
  | Replace => history->RelayRouter__History.replace(queryParams->QueryParams.toString)
  }
}

type setQueryParamsFnConfig = {
  applyQueryParams: RelayRouter__Bindings.QueryParams.t => unit,
  currentSearch: string,
  navigationMode_: RelayRouter__Types.setQueryParamsMode,
  removeNotControlledParams: bool,
  shallow: bool,
}

type setQueryParamsFn = setQueryParamsFnConfig => unit

let useSetQueryParams = () => {
  let router = RelayRouter__Context.useRouterContext()

  let setQueryParamsFn: setQueryParamsFn = React.useCallback(
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
    [router],
  )

  setQueryParamsFn
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
