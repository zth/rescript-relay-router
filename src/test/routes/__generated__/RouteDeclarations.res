
@val external suspend: Js.Promise.t<'any> => unit = "throw"

exception Route_loading_failed(string)


module type T__Root = module type of Root_route_renderer
@val external import__Root: (@as(json`"@rescriptModule/Root_route_renderer"`) _, unit) => Js.Promise.t<module(T__Root)> = "import"

module type T__Root__Todos = module type of Root__Todos_route_renderer
@val external import__Root__Todos: (@as(json`"@rescriptModule/Root__Todos_route_renderer"`) _, unit) => Js.Promise.t<module(T__Root__Todos)> = "import"

module type T__Root__Todos__Single = module type of Root__Todos__Single_route_renderer
@val external import__Root__Todos__Single: (@as(json`"@rescriptModule/Root__Todos__Single_route_renderer"`) _, unit) => Js.Promise.t<module(T__Root__Todos__Single)> = "import"

type loadedRouteRenderer<'routeRendererModule> = NotInitiated | Pending(Js.Promise.t<'routeRendererModule>) | Loaded('routeRendererModule)

type loadedRouteRendererMap = {
  mutable renderer_Root: loadedRouteRenderer<module(T__Root)>,
  mutable renderer_Root__Todos: loadedRouteRenderer<module(T__Root__Todos)>,
  mutable renderer_Root__Todos__Single: loadedRouteRenderer<module(T__Root__Todos__Single)>,
}

let loadedRouteRenderers: loadedRouteRendererMap = {
  renderer_Root: NotInitiated,
  renderer_Root__Todos: NotInitiated,
  renderer_Root__Todos__Single: NotInitiated,
}

type preparedContainer = {
  dispose: (. unit) => unit,
  render: RelayRouter.Types.renderRouteFn,
  mutable timeout: option<Js.Global.timeoutId>
}

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

  [
      {
    let loadRouteRenderer = () => {
      let promise = import__Root()
      loadedRouteRenderers.renderer_Root = Pending(promise)
  
      promise->Js.Promise.then_(m => {
        let module(M: T__Root) = m
        loadedRouteRenderers.renderer_Root = Loaded(module(M))
        Js.Promise.resolve()
      }, _)
    }
  
    {
      path: "/",
      loadRouteRenderer,
      preloadCode: (
        . ~environment: RescriptRelay.Environment.t,
        ~pathParams: Js.Dict.t<string>,
        ~queryParams: RelayRouter.Bindings.QueryParams.t,
        ~location: RelayRouter.Bindings.History.location,
      ) => {
        let apply = (module(RouteRenderer: T__Root)) => {
          let preparedProps = Route__Root_route.makePrepareProps(.
            ~environment,
            ~pathParams,
            ~queryParams,
            ~location,
          )
        
          switch RouteRenderer.renderer.prepareCode {
            | Some(prepareCode) => prepareCode(. preparedProps)
            | None => []
          }
        }
  
        switch loadedRouteRenderers.renderer_Root {
        | NotInitiated => loadRouteRenderer()->Js.Promise.then_(() => {
          switch loadedRouteRenderers.renderer_Root {
            | Loaded(module(RouteRenderer)) => module(RouteRenderer)->apply->Js.Promise.resolve
            | _ => raise(Route_loading_failed("Invalid state after loading route renderer. Please report this error."))
          }
        }, _)
        | Pending(promise) => promise->Js.Promise.then_((module(RouteRenderer: T__Root)) => {
            module(RouteRenderer)->apply->Js.Promise.resolve
          }, _)
        | Loaded(module(RouteRenderer)) => 
          Js.Promise.make((~resolve, ~reject as _) => {
            resolve(. apply(module(RouteRenderer)))
          })
        }
      },
      prepare: (
        . ~environment: RescriptRelay.Environment.t,
        ~pathParams: Js.Dict.t<string>,
        ~queryParams: RelayRouter.Bindings.QueryParams.t,
        ~location: RelayRouter.Bindings.History.location,
      ) => {
        let preparedProps = Route__Root_route.makePrepareProps(.
          ~environment,
          ~pathParams,
          ~queryParams,
          ~location,
        )
        let routeKey = Route__Root_route.makeRouteKey(~pathParams, ~queryParams)
  
        switch getPrepared(~routeKey) {
          | Some({render}) => render
          | None => 
  
          let preparedRef = ref(NotInitiated)
  
          let doPrepare = (module(RouteRenderer: T__Root)) => {
            switch RouteRenderer.renderer.prepareCode {
            | Some(prepareCode) =>
              let _ = prepareCode(. preparedProps)
            | None => ()
            }
  
            let prepared = RouteRenderer.renderer.prepare(preparedProps)
            preparedRef.contents = Loaded(prepared)
  
            prepared
          }
          
          switch loadedRouteRenderers.renderer_Root {
          | NotInitiated =>
            let preparePromise = loadRouteRenderer()->Js.Promise.then_(() => {
              switch loadedRouteRenderers.renderer_Root {
              | Loaded(module(RouteRenderer)) => doPrepare(module(RouteRenderer))->Js.Promise.resolve
              | _ => raise(Route_loading_failed("Route renderer not in loaded state even though it should be. This should be impossible, please report this error."))
              }
            }, _)
            preparedRef.contents = Pending(preparePromise)
          | Pending(promise) =>
            let preparePromise = promise->Js.Promise.then_((module(RouteRenderer: T__Root)) => {
              doPrepare(module(RouteRenderer))->Js.Promise.resolve
            }, _)
            preparedRef.contents = Pending(preparePromise)
          | Loaded(module(RouteRenderer)) => let _ = doPrepare(module(RouteRenderer))
          }
  
          let render = (. ~childRoutes) => {
            React.useEffect0(() => {
              clearTimeout(~routeKey)
  
              Some(() => {
                expirePrepared(~routeKey)
              })
            })
  
            switch (
              loadedRouteRenderers.renderer_Root,
              preparedRef.contents,
            ) {
            | (_, NotInitiated) =>
              Js.log(
                "Warning: Tried to render route with prepared not initiated. This should not happen, prepare should be called prior to any rendering.",
              )
              React.null
            | (_, Pending(promise)) =>
              suspend(promise)
              React.null
            | (Loaded(module(RouteRenderer: T__Root)), Loaded(prepared)) =>
              RouteRenderer.renderer.render({
                environment: environment,
                childRoutes: childRoutes,
                location: location,
                prepared: prepared,
  
  
              })
            | _ =>
              Js.log("Warning: Invalid state")
              React.null
            }
          }
  
          addPrepared(~routeKey, ~render, ~dispose=(. ) => {
            switch preparedRef.contents {
              | Loaded(prepared) => 
                RelayRouter.Internal.extractDisposables(. prepared)
                ->Belt.Array.forEach(dispose => {
                  dispose(.)
                })
              | _ => ()
            }
          })
  
          render
        }
      },
      children: [    {
        let loadRouteRenderer = () => {
          let promise = import__Root__Todos()
          loadedRouteRenderers.renderer_Root__Todos = Pending(promise)
      
          promise->Js.Promise.then_(m => {
            let module(M: T__Root__Todos) = m
            loadedRouteRenderers.renderer_Root__Todos = Loaded(module(M))
            Js.Promise.resolve()
          }, _)
        }
      
        {
          path: "todos",
          loadRouteRenderer,
          preloadCode: (
            . ~environment: RescriptRelay.Environment.t,
            ~pathParams: Js.Dict.t<string>,
            ~queryParams: RelayRouter.Bindings.QueryParams.t,
            ~location: RelayRouter.Bindings.History.location,
          ) => {
            let apply = (module(RouteRenderer: T__Root__Todos)) => {
              let preparedProps = Route__Root__Todos_route.makePrepareProps(.
                ~environment,
                ~pathParams,
                ~queryParams,
                ~location,
              )
            
              switch RouteRenderer.renderer.prepareCode {
                | Some(prepareCode) => prepareCode(. preparedProps)
                | None => []
              }
            }
      
            switch loadedRouteRenderers.renderer_Root__Todos {
            | NotInitiated => loadRouteRenderer()->Js.Promise.then_(() => {
              switch loadedRouteRenderers.renderer_Root__Todos {
                | Loaded(module(RouteRenderer)) => module(RouteRenderer)->apply->Js.Promise.resolve
                | _ => raise(Route_loading_failed("Invalid state after loading route renderer. Please report this error."))
              }
            }, _)
            | Pending(promise) => promise->Js.Promise.then_((module(RouteRenderer: T__Root__Todos)) => {
                module(RouteRenderer)->apply->Js.Promise.resolve
              }, _)
            | Loaded(module(RouteRenderer)) => 
              Js.Promise.make((~resolve, ~reject as _) => {
                resolve(. apply(module(RouteRenderer)))
              })
            }
          },
          prepare: (
            . ~environment: RescriptRelay.Environment.t,
            ~pathParams: Js.Dict.t<string>,
            ~queryParams: RelayRouter.Bindings.QueryParams.t,
            ~location: RelayRouter.Bindings.History.location,
          ) => {
            let preparedProps = Route__Root__Todos_route.makePrepareProps(.
              ~environment,
              ~pathParams,
              ~queryParams,
              ~location,
            )
            let routeKey = Route__Root__Todos_route.makeRouteKey(~pathParams, ~queryParams)
      
            switch getPrepared(~routeKey) {
              | Some({render}) => render
              | None => 
      
              let preparedRef = ref(NotInitiated)
      
              let doPrepare = (module(RouteRenderer: T__Root__Todos)) => {
                switch RouteRenderer.renderer.prepareCode {
                | Some(prepareCode) =>
                  let _ = prepareCode(. preparedProps)
                | None => ()
                }
      
                let prepared = RouteRenderer.renderer.prepare(preparedProps)
                preparedRef.contents = Loaded(prepared)
      
                prepared
              }
              
              switch loadedRouteRenderers.renderer_Root__Todos {
              | NotInitiated =>
                let preparePromise = loadRouteRenderer()->Js.Promise.then_(() => {
                  switch loadedRouteRenderers.renderer_Root__Todos {
                  | Loaded(module(RouteRenderer)) => doPrepare(module(RouteRenderer))->Js.Promise.resolve
                  | _ => raise(Route_loading_failed("Route renderer not in loaded state even though it should be. This should be impossible, please report this error."))
                  }
                }, _)
                preparedRef.contents = Pending(preparePromise)
              | Pending(promise) =>
                let preparePromise = promise->Js.Promise.then_((module(RouteRenderer: T__Root__Todos)) => {
                  doPrepare(module(RouteRenderer))->Js.Promise.resolve
                }, _)
                preparedRef.contents = Pending(preparePromise)
              | Loaded(module(RouteRenderer)) => let _ = doPrepare(module(RouteRenderer))
              }
      
              let render = (. ~childRoutes) => {
                React.useEffect0(() => {
                  clearTimeout(~routeKey)
      
                  Some(() => {
                    expirePrepared(~routeKey)
                  })
                })
      
                switch (
                  loadedRouteRenderers.renderer_Root__Todos,
                  preparedRef.contents,
                ) {
                | (_, NotInitiated) =>
                  Js.log(
                    "Warning: Tried to render route with prepared not initiated. This should not happen, prepare should be called prior to any rendering.",
                  )
                  React.null
                | (_, Pending(promise)) =>
                  suspend(promise)
                  React.null
                | (Loaded(module(RouteRenderer: T__Root__Todos)), Loaded(prepared)) =>
                  RouteRenderer.renderer.render({
                    environment: environment,
                    childRoutes: childRoutes,
                    location: location,
                    prepared: prepared,
      
      
                  })
                | _ =>
                  Js.log("Warning: Invalid state")
                  React.null
                }
              }
      
              addPrepared(~routeKey, ~render, ~dispose=(. ) => {
                switch preparedRef.contents {
                  | Loaded(prepared) => 
                    RelayRouter.Internal.extractDisposables(. prepared)
                    ->Belt.Array.forEach(dispose => {
                      dispose(.)
                    })
                  | _ => ()
                }
              })
      
              render
            }
          },
          children: [      {
              let loadRouteRenderer = () => {
                let promise = import__Root__Todos__Single()
                loadedRouteRenderers.renderer_Root__Todos__Single = Pending(promise)
            
                promise->Js.Promise.then_(m => {
                  let module(M: T__Root__Todos__Single) = m
                  loadedRouteRenderers.renderer_Root__Todos__Single = Loaded(module(M))
                  Js.Promise.resolve()
                }, _)
              }
            
              {
                path: ":todoId",
                loadRouteRenderer,
                preloadCode: (
                  . ~environment: RescriptRelay.Environment.t,
                  ~pathParams: Js.Dict.t<string>,
                  ~queryParams: RelayRouter.Bindings.QueryParams.t,
                  ~location: RelayRouter.Bindings.History.location,
                ) => {
                  let apply = (module(RouteRenderer: T__Root__Todos__Single)) => {
                    let preparedProps = Route__Root__Todos__Single_route.makePrepareProps(.
                      ~environment,
                      ~pathParams,
                      ~queryParams,
                      ~location,
                    )
                  
                    switch RouteRenderer.renderer.prepareCode {
                      | Some(prepareCode) => prepareCode(. preparedProps)
                      | None => []
                    }
                  }
            
                  switch loadedRouteRenderers.renderer_Root__Todos__Single {
                  | NotInitiated => loadRouteRenderer()->Js.Promise.then_(() => {
                    switch loadedRouteRenderers.renderer_Root__Todos__Single {
                      | Loaded(module(RouteRenderer)) => module(RouteRenderer)->apply->Js.Promise.resolve
                      | _ => raise(Route_loading_failed("Invalid state after loading route renderer. Please report this error."))
                    }
                  }, _)
                  | Pending(promise) => promise->Js.Promise.then_((module(RouteRenderer: T__Root__Todos__Single)) => {
                      module(RouteRenderer)->apply->Js.Promise.resolve
                    }, _)
                  | Loaded(module(RouteRenderer)) => 
                    Js.Promise.make((~resolve, ~reject as _) => {
                      resolve(. apply(module(RouteRenderer)))
                    })
                  }
                },
                prepare: (
                  . ~environment: RescriptRelay.Environment.t,
                  ~pathParams: Js.Dict.t<string>,
                  ~queryParams: RelayRouter.Bindings.QueryParams.t,
                  ~location: RelayRouter.Bindings.History.location,
                ) => {
                  let preparedProps = Route__Root__Todos__Single_route.makePrepareProps(.
                    ~environment,
                    ~pathParams,
                    ~queryParams,
                    ~location,
                  )
                  let routeKey = Route__Root__Todos__Single_route.makeRouteKey(~pathParams, ~queryParams)
            
                  switch getPrepared(~routeKey) {
                    | Some({render}) => render
                    | None => 
            
                    let preparedRef = ref(NotInitiated)
            
                    let doPrepare = (module(RouteRenderer: T__Root__Todos__Single)) => {
                      switch RouteRenderer.renderer.prepareCode {
                      | Some(prepareCode) =>
                        let _ = prepareCode(. preparedProps)
                      | None => ()
                      }
            
                      let prepared = RouteRenderer.renderer.prepare(preparedProps)
                      preparedRef.contents = Loaded(prepared)
            
                      prepared
                    }
                    
                    switch loadedRouteRenderers.renderer_Root__Todos__Single {
                    | NotInitiated =>
                      let preparePromise = loadRouteRenderer()->Js.Promise.then_(() => {
                        switch loadedRouteRenderers.renderer_Root__Todos__Single {
                        | Loaded(module(RouteRenderer)) => doPrepare(module(RouteRenderer))->Js.Promise.resolve
                        | _ => raise(Route_loading_failed("Route renderer not in loaded state even though it should be. This should be impossible, please report this error."))
                        }
                      }, _)
                      preparedRef.contents = Pending(preparePromise)
                    | Pending(promise) =>
                      let preparePromise = promise->Js.Promise.then_((module(RouteRenderer: T__Root__Todos__Single)) => {
                        doPrepare(module(RouteRenderer))->Js.Promise.resolve
                      }, _)
                      preparedRef.contents = Pending(preparePromise)
                    | Loaded(module(RouteRenderer)) => let _ = doPrepare(module(RouteRenderer))
                    }
            
                    let render = (. ~childRoutes) => {
                      React.useEffect0(() => {
                        clearTimeout(~routeKey)
            
                        Some(() => {
                          expirePrepared(~routeKey)
                        })
                      })
            
                      switch (
                        loadedRouteRenderers.renderer_Root__Todos__Single,
                        preparedRef.contents,
                      ) {
                      | (_, NotInitiated) =>
                        Js.log(
                          "Warning: Tried to render route with prepared not initiated. This should not happen, prepare should be called prior to any rendering.",
                        )
                        React.null
                      | (_, Pending(promise)) =>
                        suspend(promise)
                        React.null
                      | (Loaded(module(RouteRenderer: T__Root__Todos__Single)), Loaded(prepared)) =>
                        RouteRenderer.renderer.render({
                          environment: environment,
                          childRoutes: childRoutes,
                          location: location,
                          prepared: prepared,
                            todoId: preparedProps.todoId,
                            showMore: preparedProps.showMore,
                        })
                      | _ =>
                        Js.log("Warning: Invalid state")
                        React.null
                      }
                    }
            
                    addPrepared(~routeKey, ~render, ~dispose=(. ) => {
                      switch preparedRef.contents {
                        | Loaded(prepared) => 
                          RelayRouter.Internal.extractDisposables(. prepared)
                          ->Belt.Array.forEach(dispose => {
                            dispose(.)
                          })
                        | _ => ()
                      }
                    })
            
                    render
                  }
                },
                children: [],
              }
            }],
        }
      }],
    }
  }
  ]
}