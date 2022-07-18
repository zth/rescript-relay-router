open RelayRouter__Types

let setQueryParams = (queryParams, mode, history) => {
  open RelayRouter__Bindings

  switch mode {
  | Push => history->History.push(queryParams->QueryParams.toString)
  | Replace => history->History.replace(queryParams->QueryParams.toString)
  }
}

type pathMatch

@module("react-router") @return(nullable)
external matchPath: (string, string) => option<pathMatch> = "matchPath"

@module("react-router") @return(nullable)
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

let runAtPriority = (cb, ~priority) => {
  if !RelaySSRUtils.ssr {
    switch priority {
    | Low =>
      // On low priority, let the browser wait as long as needed
      let id = requestIdleCallback(cb, None)
      Some(() => cancelIdleCallback(id))
    | Default =>
      // On default priority, ensure loading starts within 2s
      let id = requestIdleCallback(cb, Some({"timeout": 2000}))
      Some(() => cancelIdleCallback(id))
    | High =>
      // High priority means we'll run it right away
      cb()
      None
    }
  } else {
    None
  }
}
