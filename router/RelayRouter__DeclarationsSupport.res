@val external suspend: Js.Promise.t<'any> => unit = "throw"

exception Route_loading_failed(string)

type prepareProps
type prepared
type renderProps

@val
external unsafe_createRenderProps: (
  {"prepared": prepared},
  {"childRoutes": React.element},
  prepareProps,
) => renderProps = "Object.assign"

module RouteRenderer = {
  type routeRenderer = {
    prepareCode: option<(. prepareProps) => array<RelayRouterTypes.preloadAsset>>,
    prepare: (. prepareProps) => prepared,
    render: (. renderProps) => React.element,
  }

  type t = {renderer: routeRenderer}
}

type suspenseEnabledHolder<'thing> = NotInitiated | Pending(Js.Promise.t<'thing>) | Loaded('thing)

type loadedRouteRenderer = suspenseEnabledHolder<RouteRenderer.t>

type preparedContainer = {
  dispose: (. unit) => unit,
  render: RelayRouter.Types.renderRouteFn,
  mutable timeout: option<Js.Global.timeoutId>,
}

type makePrepareProps = (
  . ~environment: RescriptRelay.Environment.t,
  ~pathParams: Js.Dict.t<string>,
  ~queryParams: RelayRouter.Bindings.QueryParams.t,
  ~location: RelayRouter.Bindings.History.location,
) => prepareProps

let doLoadRouteRenderer = (
  loadFn: unit => Js.Promise.t<RouteRenderer.t>,
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

let preloadCode = (
  ~loadedRouteRenderers,
  ~routeName,
  ~loadRouteRenderer,
  ~makePrepareProps: makePrepareProps,
  ~environment,
  ~pathParams,
  ~queryParams,
  ~location,
) => {
  let apply = (routeRenderer: RouteRenderer.t) => {
    let preparedProps = makePrepareProps(. ~environment, ~pathParams, ~queryParams, ~location)

    switch routeRenderer.renderer.prepareCode {
    | Some(prepareCode) => prepareCode(. preparedProps)
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
      resolve(. apply(routeRenderer))
    })
  }
}

type prepareAssets = {
  getPrepared: (~routeKey: Belt.HashMap.String.key) => option<preparedContainer>,
  prepareRoute: (
    . ~environment: RescriptRelay.Environment.t,
    ~pathParams: Js.Dict.t<string>,
    ~queryParams: RelayRouter.Bindings.QueryParams.t,
    ~location: RelayRouter.Bindings.History.location,
    ~makePrepareProps: (
      . ~environment: RescriptRelay.Environment.t,
      ~pathParams: Js.Dict.t<string>,
      ~queryParams: RelayRouter.Bindings.QueryParams.t,
      ~location: RelayRouter.Bindings.History.location,
    ) => prepareProps,
    ~makeRouteKey: (
      ~pathParams: Js.Dict.t<string>,
      ~queryParams: RelayRouter.Bindings.QueryParams.t,
    ) => string,
    ~getPrepared: (~routeKey: Belt.HashMap.String.key) => option<preparedContainer>,
    ~routeName: string,
    ~loadRouteRenderer: unit => Js.Promise.t<unit>,
  ) => RelayRouter.Types.renderRouteFn,
}

let makePrepareAssets = (~loadedRouteRenderers, ~prepareDisposeTimeout): prepareAssets => {
  let preparedMap: Belt.HashMap.String.t<preparedContainer> = Belt.HashMap.String.make(~hintSize=3)

  let getPrepared = (~routeKey) => preparedMap->Belt.HashMap.String.get(routeKey)

  let disposeOfPrepared = (~routeKey) => {
    switch getPrepared(~routeKey) {
    | None => ()
    | Some({dispose}) => dispose(.)
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
          disposeOfPrepared(~routeKey)
          expirePrepared(~routeKey)
        }, prepareDisposeTimeout))
    | None => ()
    }
  }

  let addPrepared = (~routeKey, ~dispose, ~render) => {
    preparedMap->Belt.HashMap.String.set(
      routeKey,
      {
        dispose: dispose,
        render: render,
        timeout: None,
      },
    )

    setTimeout(~routeKey)
  }

  let prepareRoute = (
    . ~environment: RescriptRelay.Environment.t,
    ~pathParams: Js.Dict.t<string>,
    ~queryParams: RelayRouter.Bindings.QueryParams.t,
    ~location: RelayRouter.Bindings.History.location,
    ~makePrepareProps: (
      . ~environment: RescriptRelay.Environment.t,
      ~pathParams: Js.Dict.t<string>,
      ~queryParams: RelayRouter.Bindings.QueryParams.t,
      ~location: RelayRouter.Bindings.History.location,
    ) => prepareProps,
    ~makeRouteKey: (
      ~pathParams: Js.Dict.t<string>,
      ~queryParams: RelayRouter.Bindings.QueryParams.t,
    ) => string,
    ~getPrepared: (~routeKey: Belt.HashMap.String.key) => option<preparedContainer>,
    ~routeName: string,
    ~loadRouteRenderer,
  ) => {
    let preparedProps = makePrepareProps(. ~environment, ~pathParams, ~queryParams, ~location)
    let routeKey = makeRouteKey(~pathParams, ~queryParams)

    switch getPrepared(~routeKey) {
    | Some({render}) => render
    | None =>
      let preparedRef: ref<suspenseEnabledHolder<prepared>> = ref(NotInitiated)

      let doPrepare = (routeRenderer: RouteRenderer.t) => {
        switch routeRenderer.renderer.prepareCode {
        | Some(prepareCode) =>
          let _ = prepareCode(. preparedProps)
        | None => ()
        }

        let prepared = routeRenderer.renderer.prepare(. preparedProps)
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

      let render = (. ~childRoutes) => {
        React.useEffect0(() => {
          clearTimeout(~routeKey)

          Some(
            () => {
              expirePrepared(~routeKey)
            },
          )
        })

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
          routeRenderer.renderer.render(.
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

      addPrepared(~routeKey, ~render, ~dispose=(. ()) => {
        switch preparedRef.contents {
        | Loaded(prepared) =>
          RelayRouter.Internal.extractDisposables(. prepared)->Belt.Array.forEach(dispose => {
            dispose(.)
          })
        | _ => ()
        }
      })

      render
    }
  }

  {
    getPrepared: getPrepared,
    prepareRoute: prepareRoute,
  }
}