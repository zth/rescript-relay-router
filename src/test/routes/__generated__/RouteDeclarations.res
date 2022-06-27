
open RelayRouter__DeclarationsSupport


@val external import__Root: (@as(json`"@rescriptModule/Root_route_renderer"`) _, unit) => Js.Promise.t<RouteRenderer.t> = "import"

@val external import__Root__Todos: (@as(json`"@rescriptModule/Root__Todos_route_renderer"`) _, unit) => Js.Promise.t<RouteRenderer.t> = "import"

@val external import__Root__Todos__Single: (@as(json`"@rescriptModule/Root__Todos__Single_route_renderer"`) _, unit) => Js.Promise.t<RouteRenderer.t> = "import"

let loadedRouteRenderers: Belt.HashMap.String.t<loadedRouteRenderer> = Belt.HashMap.String.make(
  ~hintSize=3,
)

let make = (~prepareDisposeTimeout=5 * 60 * 1000, ()): array<RelayRouter.Types.route> => {
  let preparedMap: Belt.HashMap.String.t<preparedContainer> = Belt.HashMap.String.make(~hintSize=3)

  let getPrepared = (~routeKey) => 
    preparedMap->Belt.HashMap.String.get(routeKey)

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
      | Some(r) => 
        r.timeout = Some(Js.Global.setTimeout(() => {
          disposeOfPrepared(~routeKey)
          expirePrepared(~routeKey)
        }, prepareDisposeTimeout))
      | None => ()
    }
  }

  let addPrepared = (~routeKey, ~dispose, ~render) => {
    preparedMap->Belt.HashMap.String.set(routeKey, {
      dispose,
      render,
      timeout: None
    })


    setTimeout(~routeKey)
  }

  let prepareRoute = (
    ~environment: RescriptRelay.Environment.t,
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
        switch routeRenderer.prepareCode {
        | Some(prepareCode) =>
          let _ = prepareCode(. preparedProps)
        | None => ()
        }

        let prepared = routeRenderer.prepare(. preparedProps)
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
          routeRenderer.RouteRenderer.render(.
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

  [
      {
    let routeName = "Root"
    let loadRouteRenderer = () => import__Root->doLoadRouteRenderer(~routeName, ~loadedRouteRenderers)
  
    {
      path: "/",
      name: routeName,
      chunk: "Root_route_renderer",
      loadRouteRenderer,
      preloadCode: (
        . ~environment: RescriptRelay.Environment.t,
        ~pathParams: Js.Dict.t<string>,
        ~queryParams: RelayRouter.Bindings.QueryParams.t,
        ~location: RelayRouter.Bindings.History.location,
      ) => preloadCode(
        ~loadedRouteRenderers,
        ~routeName,
        ~loadRouteRenderer,
        ~environment,
        ~location,
        ~makePrepareProps=Route__Root_route.makePrepareProps->Obj.magic,
        ~pathParams,
        ~queryParams,
      ),
      prepare: (
        . ~environment: RescriptRelay.Environment.t,
        ~pathParams: Js.Dict.t<string>,
        ~queryParams: RelayRouter.Bindings.QueryParams.t,
        ~location: RelayRouter.Bindings.History.location,
      ) => prepareRoute(
        ~environment,
        ~pathParams,
        ~queryParams,
        ~location,
        ~getPrepared,
        ~loadRouteRenderer,
        ~makePrepareProps=Route__Root_route.makePrepareProps->Obj.magic,
        ~makeRouteKey=Route__Root_route.makeRouteKey,
        ~routeName,
      ),
      children: [    {
        let routeName = "Root__Todos"
        let loadRouteRenderer = () => import__Root__Todos->doLoadRouteRenderer(~routeName, ~loadedRouteRenderers)
      
        {
          path: "todos",
          name: routeName,
          chunk: "Root__Todos_route_renderer",
          loadRouteRenderer,
          preloadCode: (
            . ~environment: RescriptRelay.Environment.t,
            ~pathParams: Js.Dict.t<string>,
            ~queryParams: RelayRouter.Bindings.QueryParams.t,
            ~location: RelayRouter.Bindings.History.location,
          ) => preloadCode(
            ~loadedRouteRenderers,
            ~routeName,
            ~loadRouteRenderer,
            ~environment,
            ~location,
            ~makePrepareProps=Route__Root__Todos_route.makePrepareProps->Obj.magic,
            ~pathParams,
            ~queryParams,
          ),
          prepare: (
            . ~environment: RescriptRelay.Environment.t,
            ~pathParams: Js.Dict.t<string>,
            ~queryParams: RelayRouter.Bindings.QueryParams.t,
            ~location: RelayRouter.Bindings.History.location,
          ) => prepareRoute(
            ~environment,
            ~pathParams,
            ~queryParams,
            ~location,
            ~getPrepared,
            ~loadRouteRenderer,
            ~makePrepareProps=Route__Root__Todos_route.makePrepareProps->Obj.magic,
            ~makeRouteKey=Route__Root__Todos_route.makeRouteKey,
            ~routeName,
          ),
          children: [      {
              let routeName = "Root__Todos__Single"
              let loadRouteRenderer = () => import__Root__Todos__Single->doLoadRouteRenderer(~routeName, ~loadedRouteRenderers)
            
              {
                path: ":todoId",
                name: routeName,
                chunk: "Root__Todos__Single_route_renderer",
                loadRouteRenderer,
                preloadCode: (
                  . ~environment: RescriptRelay.Environment.t,
                  ~pathParams: Js.Dict.t<string>,
                  ~queryParams: RelayRouter.Bindings.QueryParams.t,
                  ~location: RelayRouter.Bindings.History.location,
                ) => preloadCode(
                  ~loadedRouteRenderers,
                  ~routeName,
                  ~loadRouteRenderer,
                  ~environment,
                  ~location,
                  ~makePrepareProps=Route__Root__Todos__Single_route.makePrepareProps->Obj.magic,
                  ~pathParams,
                  ~queryParams,
                ),
                prepare: (
                  . ~environment: RescriptRelay.Environment.t,
                  ~pathParams: Js.Dict.t<string>,
                  ~queryParams: RelayRouter.Bindings.QueryParams.t,
                  ~location: RelayRouter.Bindings.History.location,
                ) => prepareRoute(
                  ~environment,
                  ~pathParams,
                  ~queryParams,
                  ~location,
                  ~getPrepared,
                  ~loadRouteRenderer,
                  ~makePrepareProps=Route__Root__Todos__Single_route.makePrepareProps->Obj.magic,
                  ~makeRouteKey=Route__Root__Todos__Single_route.makeRouteKey,
                  ~routeName,
                ),
                children: [],
              }
            }],
        }
      }],
    }
  }
  ]
}