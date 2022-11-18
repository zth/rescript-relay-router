module Types = RelayRouter__Types
module Bindings = RelayRouter__Bindings
module Link = RelayRouter__Link
module Scroll = RelayRouter__Scroll
module AssetPreloader = RelayRouter__AssetPreloader
module NetworkUtils = RelayRouter__NetworkUtils
module PreloadInsertingStream = RelayRouter__PreloadInsertingStream
module Manifest = RelayRouter__Manifest
module History = RelayRouter__History

// TODO: This is now exposing RelayRouter internals because it's needed by the generated code.
module Internal = RelayRouter__Internal
module Utils = RelayRouter__Utils

open Types
open Bindings

@module("react-router") @return(nullable)
external matchRoutes: (array<route>, RelayRouter__History.location) => option<array<routeMatch>> =
  "matchRoutes"

let prepareMatches = (
  matches: array<routeMatch>,
  ~environment: RescriptRelay.Environment.t,
  ~queryParams: Bindings.QueryParams.t,
  ~location: RelayRouter__History.location,
): array<preparedMatch> => {
  matches->Js.Array2.map(match => {
    let {render, routeKey} = match.route.prepare(.
      ~pathParams=match.params,
      ~environment,
      ~queryParams,
      ~location,
      ~intent=Render,
    )
    {
      routeKey,
      render,
    }
  })
}

module RouterEnvironment = {
  type t = RelayRouter__History.t
  let makeBrowserEnvironment = () => RelayRouter__History.createBrowserHistory()
  let makeServerEnvironment = (~initialUrl) =>
    RelayRouter__History.createMemoryHistory(~options={"initialEntries": [initialUrl]})
}

module Router = {
  let dictDelete: (
    Js.Dict.t<'any>,
    string,
  ) => unit = %raw(`function(dict, key) { delete dict[key] }`)

  @val
  external origin: string = "window.location.origin"

  let make = (
    ~routes,
    ~routerEnvironment as history,
    ~environment,
    ~preloadAsset: Types.preloadAssetFn,
  ) => {
    let routerEventListeners = ref([])
    let postRouterEvent = event => {
      routerEventListeners.contents->Belt.Array.forEach(cb => cb(event))
    }

    let matchLocation = matchRoutes(routes)
    let location = RelayRouter__History.getLocation(history)
    let initialQueryParams = QueryParams.parse(location.search)
    let initialMatches = matchLocation(location)->Belt.Option.getWithDefault([])

    // Preload initially matched route renderers asap, we know we'll need them.
    initialMatches->Belt.Array.forEach(({route}) => {
      Types.Component({
        chunk: route.chunk,
        load: () => route.loadRouteRenderer()->ignore,
      })->preloadAsset(~priority=High)
    })

    let preparedMatches =
      initialMatches->prepareMatches(~environment, ~queryParams=initialQueryParams, ~location)

    let currentEntry = ref({
      location,
      preparedMatches,
    })

    let nextId = ref(0)
    let subscribers = Js.Dict.empty()
    let nextNavigationIsShallow = ref(false)

    let cleanup = history->RelayRouter__History.listen(({location}) => {
      let thisNavigationShouldBeShallow = nextNavigationIsShallow.contents
      if nextNavigationIsShallow.contents === true {
        nextNavigationIsShallow.contents = false
      }
      if (
        !thisNavigationShouldBeShallow &&
        (location.pathname !== currentEntry.contents.location.pathname ||
          location.search !== currentEntry.contents.location.search)
      ) {
        let queryParams = QueryParams.parse(location.search)

        let currentMatches = currentEntry.contents.preparedMatches

        let matches = matchLocation(location)->Belt.Option.getWithDefault([])
        let preparedMatches = matches->prepareMatches(~environment, ~queryParams, ~location)
        currentEntry.contents = {
          location,
          preparedMatches,
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
        RelayRouter__History.pathname: url->URL.getPathname,
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

    @live
    let preloadCode = (~priority=Default, preloadUrl) => {
      preloadUrl->runOnEachRouteMatch((~match, ~queryParams, ~location as _) => {
        // We don't care about the unsub callback here
        let _ = Internal.runAtPriority(() => {
          let _ = match.route.preloadCode(.
            ~environment,
            ~pathParams=match.params,
            ~queryParams,
            ~location,
          )->Js.Promise.then_(
            assetsToPreload => {
              assetsToPreload->Belt.Array.forEach(preloadAsset(~priority))
              Js.Promise.resolve()
            },
            _,
          )
        }, ~priority)
      })
    }

    @live
    let preload = (~priority=Default, preloadUrl) => {
      preloadUrl->runOnEachRouteMatch((~match, ~queryParams, ~location) => {
        // We don't care about the render function returned to us when
        // preparing, and we don't care about the run priority unsub
        let _ = Internal.runAtPriority(() => {
          let _: preparedRoute = match.route.prepare(.
            ~environment,
            ~pathParams=match.params,
            ~queryParams,
            ~location,
            ~intent=Preload,
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

    // This is intentionally very basic starting out, as in using this will
    // block _all_ route loading for the next navigation. In the future one
    // might imagine this taking a routeName so that we can block route loaders
    // only for the route segment this was triggered from. That would be useful
    // in cases where multiple route segments need to react to the same query
    // param.
    let markNextNavigationAsShallow = () => {
      nextNavigationIsShallow.contents = true
    }

    (
      cleanup,
      {
        preloadCode,
        preload,
        preloadAsset,
        get,
        subscribe,
        history,
        subscribeToEvent: callback => {
          let _ = routerEventListeners.contents->Js.Array2.push(callback)

          () => {
            routerEventListeners.contents =
              routerEventListeners.contents->Belt.Array.keep(cb => cb !== callback)
          }
        },
        postRouterEvent,
        markNextNavigationAsShallow,
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
  let make = (~renderPending=?, ()) => {
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
      {renderedContent.contents}
    </>
  }
}

@live
let useRegisterPreloadedAsset = asset => {
  let {preloadAsset} = useRouterContext()
  try {
    if RelaySSRUtils.ssr {
      asset->preloadAsset(~priority=Default)
    }
  } catch {
  | Js.Exn.Error(_) => ()
  }
}
