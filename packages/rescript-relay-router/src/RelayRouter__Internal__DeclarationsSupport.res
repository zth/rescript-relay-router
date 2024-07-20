@val external suspend: promise<'any> => unit = "throw"

exception Route_loading_failed(string)

type prepareProps
type prepared
type renderProps

//  This works because the render props for a route is always the prepared props
//  + prepared + childRoutes. If that changes, this will also need to change
//  accordingly.
@val
external unsafe_createRenderProps: (
  {"prepared": prepared},
  {"childRoutes": React.element},
  prepareProps,
) => renderProps = "Object.assign"

module RouteRenderer = {
  type t = {
    prepareCode: option<prepareProps => array<RelayRouter__Types.preloadAsset>>,
    prepare: prepareProps => prepared,
    render: renderProps => React.element,
  }
}

// This holder makes it easy to suspend (throwing the promise) or synchronously
// return the loaded thing once availabile.
type suspenseEnabledHolder<'thing> = NotInitiated | Pending(promise<'thing>) | Loaded('thing)

type loadedRouteRenderer = suspenseEnabledHolder<RouteRenderer.t>

// This holds meta data for a route that has been prepared.
type preparedContainer = {
  disposables: array<unit => unit>,
  render: RelayRouter.Types.renderRouteFn,
  mutable timeout: option<Js.Global.timeoutId>,
}

type makePrepareProps = (
  ~environment: RescriptRelay.Environment.t,
  ~pathParams: Js.Dict.t<string>,
  ~queryParams: RelayRouter.Bindings.QueryParams.t,
  ~location: RelayRouter__History.location,
) => prepareProps

let doLoadRouteRenderer = (
  loadFn: unit => promise<RouteRenderer.t>,
  ~routeName,
  ~loadedRouteRenderers,
) => {
  let promise = loadFn()
  loadedRouteRenderers->Belt.HashMap.String.set(routeName, Pending(promise))

  promise->Js.Promise.then_(routeRenderer => {
    loadedRouteRenderers->Belt.HashMap.String.set(routeName, Loaded(routeRenderer))
    Js.Promise.resolve()
  }, _)
}

// This does a bunch of suspense/React gymnastics for kicking off code
// preloading for a matched route..
let preloadCode = (
  ~loadedRouteRenderers,
  ~routeName,
  ~loadRouteRenderer,
  ~makePrepareProps,
  ~environment,
  ~pathParams,
  ~queryParams,
  ~location,
) => {
  let apply = (routeRenderer: RouteRenderer.t) => {
    let preparedProps = makePrepareProps(~environment, ~pathParams, ~queryParams, ~location)

    switch routeRenderer.prepareCode {
    | Some(prepareCode) => prepareCode(preparedProps)
    | None => []
    }
  }

  switch loadedRouteRenderers->Belt.HashMap.String.get(routeName) {
  | None | Some(NotInitiated) => loadRouteRenderer()->Js.Promise.then_(() => {
      switch loadedRouteRenderers->Belt.HashMap.String.get(routeName) {
      | Some(Loaded(routeRenderer)) => routeRenderer->apply->Js.Promise.resolve
      | _ =>
        raise(
          Route_loading_failed(
            "Invalid state after loading route renderer. Please report this error.",
          ),
        )
      }
    }, _)
  | Some(Pending(promise)) => promise->Js.Promise.then_(routeRenderer => {
      routeRenderer->apply->Js.Promise.resolve
    }, _)
  | Some(Loaded(routeRenderer)) =>
    Js.Promise.make((~resolve, ~reject as _) => {
      resolve(apply(routeRenderer))
    })
  }
}

type prepareAssets = {
  getPrepared: (~routeKey: Belt.HashMap.String.key) => option<preparedContainer>,
  prepareRoute: (
    ~environment: RescriptRelay.Environment.t,
    ~pathParams: Js.Dict.t<string>,
    ~queryParams: RelayRouter.Bindings.QueryParams.t,
    ~location: RelayRouter__History.location,
    ~makePrepareProps: (
      ~environment: RescriptRelay.Environment.t,
      ~pathParams: Js.Dict.t<string>,
      ~queryParams: RelayRouter.Bindings.QueryParams.t,
      ~location: RelayRouter__History.location,
    ) => prepareProps,
    ~makeRouteKey: (
      ~pathParams: Js.Dict.t<string>,
      ~queryParams: RelayRouter.Bindings.QueryParams.t,
    ) => string,
    ~getPrepared: (~routeKey: Belt.HashMap.String.key) => option<preparedContainer>,
    ~routeName: string,
    ~loadRouteRenderer: unit => promise<unit>,
    ~intent: RelayRouter__Types.prepareIntent,
  ) => RelayRouter__Types.preparedRoute,
}

// Creates the assets needed for preparing routes.
let makePrepareAssets = (~loadedRouteRenderers, ~prepareDisposeTimeout): prepareAssets => {
  let preparedMap: Belt.HashMap.String.t<preparedContainer> = Belt.HashMap.String.make(~hintSize=3)

  let getPrepared = (~routeKey) => preparedMap->Belt.HashMap.String.get(routeKey)

  let disposeOfPrepared = (~routeKey) => {
    switch getPrepared(~routeKey) {
    | None => ()
    | Some({disposables}) => disposables->Belt.Array.forEach(dispose => dispose())
    }
  }

  let clearTimeout = (~routeKey) => {
    switch getPrepared(~routeKey) {
    | Some({timeout: Some(timeoutId)}) => Js.Global.clearTimeout(timeoutId)
    | _ => ()
    }
  }

  let expirePrepared = (~routeKey) => {
    disposeOfPrepared(~routeKey)
    clearTimeout(~routeKey)
    preparedMap->Belt.HashMap.String.remove(routeKey)
  }

  let setTimeout = (~routeKey) => {
    clearTimeout(~routeKey)
    switch getPrepared(~routeKey) {
    | Some(r) => r.timeout = Some(Js.Global.setTimeout(() => {
          expirePrepared(~routeKey)
        }, prepareDisposeTimeout))
    | None => ()
    }
  }

  let addPrepared = (~routeKey, ~disposables, ~intent, ~render) => {
    let (preparedRecord, shouldSetCleanupTimeout) = switch (intent, getPrepared(~routeKey)) {
    // Set new render, and ensure the old disposables were disposed properly
    // before setting the new ones.
    | (RelayRouter.Types.Render, Some(preparedEntry)) =>
      // Clear any existing cleanup timeout for this route, because we know
      // it'll render.
      clearTimeout(~routeKey)

      // Dispose disposables within a timeout of 0 to ensure it's disposed after
      // the new query refs have had a chance to be used by React.
      let {disposables: oldDisposables} = preparedEntry

      let _ = Js.Global.setTimeout(() => {
        oldDisposables->Js.Array2.forEach(dispose => {
          dispose()
        })
      }, 0)
      (
        Some({
          ...preparedEntry,
          render,
          disposables,
        }),
        false,
      )
    // Preloading something that's already preloaded does nothing.
    | (Preload, Some(_)) => (None, false)
    // Whenever there's no existing prepared entry, set a new entry.
    | (_, None) => (
        Some({
          render,
          disposables,
          timeout: None,
        }),
        intent == Preload,
      )
    }

    switch preparedRecord {
    | None => ()
    | Some(preparedRecord) =>
      preparedMap->Belt.HashMap.String.set(routeKey, preparedRecord)

      // We set a clean up timeout for the prepared assets if this is a
      // previously unprepared route, and we're intending this as a preload
      // rather than rendering immediately.
      if shouldSetCleanupTimeout {
        setTimeout(~routeKey)
      }
    }
  }

  // This does suspense/React gymnastics for loading all the different parts
  // needed to prepare and render a route.
  let prepareRoute = (
    ~environment: RescriptRelay.Environment.t,
    ~pathParams: Js.Dict.t<string>,
    ~queryParams: RelayRouter.Bindings.QueryParams.t,
    ~location: RelayRouter__History.location,
    ~makePrepareProps: (
      ~environment: RescriptRelay.Environment.t,
      ~pathParams: Js.Dict.t<string>,
      ~queryParams: RelayRouter.Bindings.QueryParams.t,
      ~location: RelayRouter__History.location,
    ) => prepareProps,
    ~makeRouteKey: (
      ~pathParams: Js.Dict.t<string>,
      ~queryParams: RelayRouter.Bindings.QueryParams.t,
    ) => string,
    ~getPrepared: (~routeKey: Belt.HashMap.String.key) => option<preparedContainer>,
    ~routeName: string,
    ~loadRouteRenderer,
    ~intent: RelayRouter__Types.prepareIntent,
  ): RelayRouter__Types.preparedRoute => {
    let preparedProps = makePrepareProps(~environment, ~pathParams, ~queryParams, ~location)
    let routeKey = makeRouteKey(~pathParams, ~queryParams)

    // We can prepare a route with 2 different intents - either to _render_ that
    // route, or to preload it. What we do here depends on that choice.
    // 1) Preloading a route is a "nice to have", and we don't want to do that
    //    multiple times if we've already preloaded the route before. Hence, we
    //    block preparing again if prepare is called multiple times.
    // 2) However, when preparing for also _rendering_ the route, we'll always
    //    want to re-call the prepare function so the prepare is as fresh as
    //    possible.
    //
    // This is mainly because of the way Relay, preloading queries and
    // invalidating data work. Invalidating data is a powerful concept in Relay,
    // but it requires that `Query.load` is actually re-run for Relay to fetch
    // new data when data has been marked as invalid/stale. That's why we want
    // to re-run prepare on each route as we're getting it ready for rendering,
    // even if it's technically already rendered. If we don't, stale data won't
    // be automatically refetched.

    switch (getPrepared(~routeKey), intent) {
    // We don't want to preload multiple times, so just return what's already
    // prepared when calling this with the intent to Preload, and there's
    // already a prepare entry for this route.
    | (Some({render}), Preload) => {routeKey, render}
    // If calling this with the intent of rendering, we want to re-make the
    // prepare so Relay can re-evaluate and ensure that the data is fresh when
    // rendering. Do that, and ensure that any new disposables is tracked.
    | (Some(_), Render)
    | // Same goes if we had no previous prepare, do a fresh instantiation.
    (None, _) =>
      let preparedRef: ref<suspenseEnabledHolder<prepared>> = ref(NotInitiated)

      let doPrepare = (routeRenderer: RouteRenderer.t) => {
        switch routeRenderer.prepareCode {
        | Some(prepareCode) =>
          let _ = prepareCode(preparedProps)
        | None => ()
        }

        let prepared = routeRenderer.prepare(preparedProps)
        preparedRef.contents = Loaded(prepared)

        prepared
      }

      switch loadedRouteRenderers->Belt.HashMap.String.get(routeName) {
      | None | Some(NotInitiated) =>
        let preparePromise = loadRouteRenderer()->Js.Promise.then_(() => {
          switch loadedRouteRenderers->Belt.HashMap.String.get(routeName) {
          | Some(Loaded(routeRenderer)) => doPrepare(routeRenderer)->Js.Promise.resolve
          | _ =>
            raise(
              Route_loading_failed(
                "Route renderer not in loaded state even though it should be. This should be impossible, please report this error.",
              ),
            )
          }
        }, _)
        preparedRef.contents = Pending(preparePromise)
      | Some(Pending(promise)) =>
        let preparePromise = promise->Js.Promise.then_(routeRenderer => {
          doPrepare(routeRenderer)->Js.Promise.resolve
        }, _)
        preparedRef.contents = Pending(preparePromise)
      | Some(Loaded(routeRenderer)) =>
        let _ = doPrepare(routeRenderer)
      }

      let render = (~childRoutes) => {
        let {subscribeToEvent} = RelayRouter__Context.useRouterContext()

        React.useEffect(() => {
          clearTimeout(~routeKey)

          Some(
            subscribeToEvent(event => {
              switch event {
              | OnRouteWillUnmount({routeKey: unmountingRouteKey})
                if routeKey == unmountingRouteKey =>
                // TOOD: Unsure if this works as intended, or if it's a fluke.
                // In short, we need this expire to run after the route renderer
                // has been unmounted, or Relay gives us a "using preloaded
                // query that was disposed" error.
                let _ = Js.Global.setTimeout(
                  () => {
                    expirePrepared(~routeKey)
                  },
                  0,
                )
              | _ => ()
              }
            }),
          )
        }, [subscribeToEvent])

        switch (loadedRouteRenderers->Belt.HashMap.String.get(routeName), preparedRef.contents) {
        | (_, NotInitiated) =>
          Js.log(
            "Warning: Tried to render route with prepared not initiated. This should not happen, prepare should be called prior to any rendering.",
          )
          React.null
        | (_, Pending(promise)) =>
          suspend(promise)
          React.null
        | (Some(Loaded(routeRenderer)), Loaded(prepared)) =>
          routeRenderer.render(
            unsafe_createRenderProps(
              {"prepared": prepared},
              {"childRoutes": childRoutes},
              preparedProps,
            ),
          )
        | _ =>
          Js.log("Warning: Invalid state")
          React.null
        }
      }

      addPrepared(
        ~routeKey,
        ~render,
        ~intent,
        ~disposables=switch preparedRef.contents {
        | Loaded(prepared) => RelayRouter.Internal.extractDisposables(prepared)
        | _ => []
        },
      )

      {routeKey, render}
    }
  }

  {
    getPrepared,
    prepareRoute,
  }
}
