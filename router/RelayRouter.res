module Types = RelayRouter__Types
module Bindings = RelayRouter__Bindings
module Link = RelayRouter__Link
module Scroll = RelayRouter__Scroll

// TODO: This is now exposing RelayRouter internals because it's needed by the generated code.
module Internal = RelayRouter__Internal
module Utils = RelayRouter__Utils

open Types
open Bindings

@module("react-router") @return(nullable)
external matchRoutes: (array<route>, History.location) => option<array<routeMatch>> = "matchRoutes"

let prepareMatches = (
  matches: array<routeMatch>,
  ~environment: RescriptRelay.Environment.t,
  ~queryParams: Bindings.QueryParams.t,
  ~location: Bindings.History.location,
): array<preparedMatch> => {
  matches->Js.Array2.map(match => {
    let {render, routeKey} = match.route.prepare(.
      ~pathParams=match.params,
      ~environment,
      ~queryParams,
      ~location,
    )
    {
      routeKey: routeKey,
      render: render,
    }
  })
}

module RouterEnvironment = {
  type t = History.t
  let makeBrowserEnvironment = () => History.createBrowserHistory()
  let makeServerEnvironment = (~initialUrl) =>
    History.createMemoryHistory(~options={"initialEntries": [initialUrl]})
}

module PreloadAssets = {
  @val
  external appendToHead: Dom.element => unit = "document.head.appendChild"

  @val @scope("document")
  external createLinkElement: (@as("link") _, unit) => Dom.element = "createElement"

  @set
  external setHref: (Dom.element, string) => unit = "href"

  @set
  external setRel: (Dom.element, [#modulepreload | #preload]) => unit = "rel"

  @set
  external setAs: (Dom.element, [#image]) => unit = "as"

  @live
  let preloadAssetViaLinkTag = asset => {
    let element = createLinkElement()

    switch asset {
    | Component({chunk}) =>
      element->setHref(chunk)
      element->setRel(#modulepreload)
    | Image({url}) =>
      element->setHref(url)
      element->setRel(#preload)
      element->setAs(#image)
    }

    appendToHead(element)
  }
}

let _ = PreloadAssets.preloadAssetViaLinkTag

module Router = {
  let dictDelete: (
    Js.Dict.t<'any>,
    string,
  ) => unit = %raw(`function(dict, key) { delete dict[key] }`)

  @val
  external origin: string = "window.location.origin"

  let make = (~routes, ~routerEnvironment as history, ~environment) => {
    // This holds a map of all assets we've preloaded, so we can track that we
    // don't try to preload the same thing multiple times.
    let preparedAssetsMap = Js.Dict.empty()

    let routerEventListeners = ref([])
    let postRouterEvent = event => {
      routerEventListeners.contents->Belt.Array.forEach(cb => cb(event))
    }

    let matchLocation = matchRoutes(routes)
    let location = History.getLocation(history)
    let initialQueryParams = QueryParams.parse(location.search)
    let initialMatches = matchLocation(location)->Belt.Option.getWithDefault([])

    let preparedMatches =
      initialMatches->prepareMatches(~environment, ~queryParams=initialQueryParams, ~location)

    let currentEntry = ref({
      location: location,
      preparedMatches: preparedMatches,
    })

    let nextId = ref(0)
    let subscribers = Js.Dict.empty()

    let cleanup = history->History.listen(({location}) => {
      if location.pathname != currentEntry.contents.location.pathname {
        let queryParams = QueryParams.parse(location.search)

        let currentMatches = currentEntry.contents.preparedMatches

        let matches = matchLocation(location)->Belt.Option.getWithDefault([])
        let preparedMatches = matches->prepareMatches(~environment, ~queryParams, ~location)
        currentEntry.contents = {
          location: location,
          preparedMatches: preparedMatches,
        }

        // Notify anyone interested about routes that will now unmount.
        currentMatches->Belt.Array.forEach(({routeKey}) => {
          if (
            preparedMatches
            ->Belt.Array.getBy(match => match.routeKey === routeKey)
            ->Belt.Option.isNone
          ) {
            postRouterEvent(OnRouteWillUnmount({routeKey: routeKey}))
          }
        })

        subscribers
        ->Js.Dict.values
        ->Belt.Array.forEach(subscriber => subscriber(currentEntry.contents))
      }
    })

    let runOnEachRouteMatch = (preloadUrl, cb) => {
      let fullUrl = origin ++ preloadUrl
      let url = URL.make(fullUrl)
      let queryParams = url->URL.getSearch->Belt.Option.getWithDefault("")->QueryParams.parse

      let location = {
        Bindings.History.pathname: url->URL.getPathname,
        search: url->URL.getSearch->Belt.Option.getWithDefault(""),
        hash: url->URL.getHash,
        state: url->URL.getState,
        key: "-",
      }

      matchLocation(location)
      ->Belt.Option.getWithDefault([])
      ->Belt.Array.forEach(match => {
        cb(~match, ~queryParams, ~location)
      })
    }

    let doPreloadAsset = (asset, ~priority) => {
      let assetIdentifier = switch asset {
      | Component({moduleName}) => "component:" ++ moduleName
      | Image({url}) => "image:" ++ url
      }

      switch preparedAssetsMap->Js.Dict.get(assetIdentifier) {
      | Some(_) => // Already preloaded
        ()
      | None =>
        preparedAssetsMap->Js.Dict.set(assetIdentifier, true)
        switch (asset, priority) {
        | (Component(_), Default | Low) => PreloadAssets.preloadAssetViaLinkTag(asset)
        | (Component({eagerPreloadFn}), High) => eagerPreloadFn()
        | _ => // Unimplemented
          ()
        }
      }
    }

    @live
    let preloadCode = (preloadUrl, ~priority=Default, ()) => {
      let doPreloadAsset = doPreloadAsset(~priority)

      preloadUrl->runOnEachRouteMatch((~match, ~queryParams, ~location as _) => {
        // We don't care about the unsub callback here
        let _ = Internal.runAtPriority(() => {
          let _ =
            match.route.preloadCode(.
              ~environment,
              ~pathParams=match.params,
              ~queryParams,
              ~location,
            )->Js.Promise.then_(assetsToPreload => {
              assetsToPreload->Belt.Array.forEach(doPreloadAsset)
              Js.Promise.resolve()
            }, _)
        }, ~priority)
      })
    }

    @live
    let preload = (preloadUrl, ~priority=Default, ()) => {
      preloadUrl->runOnEachRouteMatch((~match, ~queryParams, ~location) => {
        // We don't care about the render function returned to us when
        // preparing, and we don't care about the run priority unsub
        let _ = Internal.runAtPriority(() => {
          let _: preparedRoute = match.route.prepare(.
            ~environment,
            ~pathParams=match.params,
            ~queryParams,
            ~location,
          )
        }, ~priority)
      })
    }

    let get = () => currentEntry.contents

    let subscribe = cb => {
      nextId.contents = nextId.contents + 1
      let id = nextId.contents
      subscribers->Js.Dict.set(Belt.Int.toString(id), cb)

      () => {
        subscribers->dictDelete(Belt.Int.toString(id))
      }
    }

    (
      cleanup,
      {
        preloadCode: preloadCode,
        preload: preload,
        get: get,
        subscribe: subscribe,
        history: history,
        subscribeToEvent: callback => {
          let _ = routerEventListeners.contents->Js.Array2.push(callback)

          () => {
            routerEventListeners.contents =
              routerEventListeners.contents->Belt.Array.keep(cb => cb !== callback)
          }
        },
        postRouterEvent: postRouterEvent,
      },
      () => {
        initialMatches
        ->Belt.Array.map(({route}) => route.loadRouteRenderer())
        ->Js.Promise.all
        ->Js.Promise.then_(_ => Js.Promise.resolve(), _)
      },
    )
  }
}

module Provider = RelayRouter__Context.Provider

let useRouterContext = RelayRouter__Context.useRouterContext

module RouteComponent = {
  @react.component
  let make = (~render: renderRouteFn, ~children) => {
    render(. ~childRoutes=children)
  }
}

module RouteRenderer = {
  @react.component
  let make = (~renderPending=?, ~renderFallback=?, ()) => {
    let router = useRouterContext()
    let (isPending, startTransition) = ReactExperimental.useTransition()
    let (routeEntry, setRouteEntry) = React.useState(() => router.get())

    if !RelaySSRUtils.ssr {
      React.useLayoutEffect1(() => {
        if !isPending {
          router.postRouterEvent(RestoreScroll(routeEntry.location))
        }
        None
      }, [isPending])
    }

    React.useEffect2(() => {
      let dispose = router.subscribe(nextRoute => {
        startTransition(() => setRouteEntry(_ => nextRoute))
      })

      Some(dispose)
    }, (router, startTransition))

    let reversedItems = routeEntry.preparedMatches->Js.Array2.copy->Js.Array2.reverseInPlace
    let renderedContent = ref(React.null)

    reversedItems->Js.Array2.forEach(({render}) => {
      renderedContent.contents = <RouteComponent render>
        {renderedContent.contents}
      </RouteComponent>
    })

    <>
      {switch renderPending {
      | Some(renderPending) => renderPending(isPending)
      | None => React.null
      }}
      <React.Suspense
        fallback={switch renderFallback {
        | Some(renderFallback) => renderFallback()
        | None => React.null
        }}>
        {renderedContent.contents}
      </React.Suspense>
    </>
  }
}

@live
let useRegisterPreloadedAsset = asset => {
  let registerAsset = RelaySSRUtils.AssetRegisterer.use()
  try {
    if RelaySSRUtils.ssr {
      registerAsset(asset)
    }
  } catch {
  | Js.Exn.Error(_) => ()
  }
}
