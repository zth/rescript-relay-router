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
      routeKey: routeKey,
      render: render,
      routeName: match.route.name,
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
    ~preloadAsset: preloadAssetFn,
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
      Component({
        chunk: route.chunk,
        load: () => route.loadRouteRenderer()->ignore,
      })->preloadAsset(~priority=High)
    })

    let preparedMatches =
      initialMatches->prepareMatches(~environment, ~queryParams=initialQueryParams, ~location)

    let currentEntry = ref({
      location: location,
      preparedMatches: preparedMatches,
    })

    let nextId = ref(0)
    let subscribers = Js.Dict.empty()

    let registeredHandlers: Js.Dict.t<routeHandler> = Js.Dict.empty()

    let cleanup = history->RelayRouter__History.listen(({location}) => {
      if (
        location.pathname != currentEntry.contents.location.pathname ||
          location.search != currentEntry.contents.location.search
      ) {
        let queryParams = QueryParams.parse(location.search)

        let currentMatches = currentEntry.contents.preparedMatches
        let matches = matchLocation(location)->Belt.Option.getWithDefault([])
        let overridenRouteHandlers = []

        // Figure out which route matches should trigger a full reload and which shouldn't
        let preparedMatches = switch location.state->History.decodeRouteState {
        | Some({shallow: Some(true), handlerId}) =>
          // This was a shallow navigation. Let's figure out if the handler it was pushed with is still around and can handle the navigation.
          switch registeredHandlers
          ->Js.Dict.values
          ->Js.Array2.find(handler => handler.handlerId == handlerId) {
          | None => None
          | Some(handler) =>
            // Yup, there's a handler. Then this route key shouldn't be refreshed even if wanted.
            matches
            ->Belt.Array.map(match => {
              let prepareThisMatch = () => {
                let {render, routeKey} = match.route.prepare(.
                  ~pathParams=match.params,
                  ~environment,
                  ~queryParams,
                  ~location,
                  ~intent=Render,
                )
                {
                  routeKey: routeKey,
                  render: render,
                  routeName: match.route.name,
                }
              }

              switch currentMatches->Js.Array2.find(m => m.routeName == handler.routeName) {
              | None => prepareThisMatch()
              | Some(currentMatch) =>
                let _ = overridenRouteHandlers->Js.Array2.push(handler)

                Js.log(
                  "route with name " ++
                  handler.routeName ++
                  " had handler with id " ++
                  handlerId ++ ", therefore skipping",
                )
                currentMatch
              }
            })
            ->Some
          }
        | _ => None
        }

        let preparedMatches = switch preparedMatches {
        | None => matches->prepareMatches(~environment, ~queryParams, ~location)
        | Some(preparedMatches) => preparedMatches
        }

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

        // Trigger any handlers. TODO: Ensure only triggers once
        overridenRouteHandlers->Js.Array2.forEach(handler => handler.handler(location))

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
          let _ =
            match.route.preloadCode(.
              ~environment,
              ~pathParams=match.params,
              ~queryParams,
              ~location,
            )->Js.Promise.then_(assetsToPreload => {
              assetsToPreload->Belt.Array.forEach(preloadAsset(~priority))
              Js.Promise.resolve()
            }, _)
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

    let registerRouteHandler = (~routeName, ~handler, ~handlerId) => {
      registeredHandlers->Js.Dict.set(
        handlerId,
        {
          routeName: routeName,
          handler: handler,
          handlerId: handlerId,
        },
      )
    }

    let unregisterRouteHandler = id => {
      Js.Dict.unsafeDeleteKey(. Obj.magic(registeredHandlers), id)
    }

    (
      cleanup,
      {
        preloadCode: preloadCode,
        preload: preload,
        preloadAsset: preloadAsset,
        get: get,
        subscribe: subscribe,
        history: history,
        unregisterRouteHandler: unregisterRouteHandler,
        registerRouteHandler: registerRouteHandler,
        subscribeToEvent: callback => {
          let _ = routerEventListeners.contents->Js.Array2.push(callback)

          () => {
            routerEventListeners.contents =
              routerEventListeners.contents->Belt.Array.keep(cb => cb !== callback)
          }
        },
        postRouterEvent: postRouterEvent,
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
