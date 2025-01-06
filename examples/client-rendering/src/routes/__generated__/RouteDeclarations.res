
open RelayRouter__Internal__DeclarationsSupport

external unsafe_toPrepareProps: 'any => prepareProps = "%identity"

let loadedRouteRenderers: Map.t<string, loadedRouteRenderer> = Map.make()

let make = (~prepareDisposeTimeout=5 * 60 * 1000): array<RelayRouter.Types.route> => {
  let {prepareRoute, getPrepared} = makePrepareAssets(~loadedRouteRenderers, ~prepareDisposeTimeout)

  [
      {
    let routeName = "Root"
    let loadRouteRenderer = () => (() => import(Root_route_renderer.renderer))->Obj.magic->doLoadRouteRenderer(~routeName, ~loadedRouteRenderers)
    let makePrepareProps = (. 
    ~environment: RescriptRelay.Environment.t,
    ~pathParams: dict<string>,
    ~queryParams: RelayRouter.Bindings.QueryParams.t,
    ~location: RelayRouter.History.location,
  ): prepareProps => {
    ignore(queryParams)
    let prepareProps: Route__Root_route.Internal.prepareProps =   {
      environment: environment,
  
      location: location,
      childParams: Obj.magic(pathParams),
    }
    prepareProps->unsafe_toPrepareProps
  }
  
    {
      path: "/",
      name: routeName,
      chunk: "Root_route_renderer",
      loadRouteRenderer,
      preloadCode: (
        ~environment: RescriptRelay.Environment.t,
        ~pathParams: dict<string>,
        ~queryParams: RelayRouter.Bindings.QueryParams.t,
        ~location: RelayRouter.History.location,
      ) => preloadCode(
        ~loadedRouteRenderers,
        ~routeName,
        ~loadRouteRenderer,
        ~environment,
        ~location,
        ~makePrepareProps,
        ~pathParams,
        ~queryParams,
      ),
      prepare: (
        ~environment: RescriptRelay.Environment.t,
        ~pathParams: dict<string>,
        ~queryParams: RelayRouter.Bindings.QueryParams.t,
        ~location: RelayRouter.History.location,
        ~intent: RelayRouter.Types.prepareIntent,
      ) => prepareRoute(
        ~environment,
        ~pathParams,
        ~queryParams,
        ~location,
        ~getPrepared,
        ~loadRouteRenderer,
        ~makePrepareProps,
        ~makeRouteKey=(
    ~pathParams: dict<string>,
    ~queryParams: RelayRouter.Bindings.QueryParams.t
  ): string => {
    ignore(pathParams)
    ignore(queryParams)
  
    "Root:"
  
  
  }
  
  ,
        ~routeName,
        ~intent
      ),
      children: [    {
        let routeName = "Root__Todos"
        let loadRouteRenderer = () => (() => import(Root__Todos_route_renderer.renderer))->Obj.magic->doLoadRouteRenderer(~routeName, ~loadedRouteRenderers)
        let makePrepareProps = (. 
        ~environment: RescriptRelay.Environment.t,
        ~pathParams: dict<string>,
        ~queryParams: RelayRouter.Bindings.QueryParams.t,
        ~location: RelayRouter.History.location,
      ): prepareProps => {
        let prepareProps: Route__Root__Todos_route.Internal.prepareProps =   {
          environment: environment,
      
          location: location,
          childParams: Obj.magic(pathParams),
          statuses: {
            let param = queryParams->RelayRouter.Bindings.QueryParams.getArrayParamByKey("statuses")
            React.useMemo(() => param->Option.map(value => value->Array.filterMap(value => value->TodoStatus.parse)), [param])
          },
          statusWithDefault: {
            let param = queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("statusWithDefault")
            React.useMemo(() => param->Option.flatMap(value => value->TodoStatus.parse)->Option.getOr(TodoStatus.defaultValue), [param])
          },
          byValue: {
            let param = queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("byValue")
            React.useMemo(() => param->Option.flatMap(value => Some(value)), [param])
          },
        }
        prepareProps->unsafe_toPrepareProps
      }
      
        {
          path: "todos",
          name: routeName,
          chunk: "Root__Todos_route_renderer",
          loadRouteRenderer,
          preloadCode: (
            ~environment: RescriptRelay.Environment.t,
            ~pathParams: dict<string>,
            ~queryParams: RelayRouter.Bindings.QueryParams.t,
            ~location: RelayRouter.History.location,
          ) => preloadCode(
            ~loadedRouteRenderers,
            ~routeName,
            ~loadRouteRenderer,
            ~environment,
            ~location,
            ~makePrepareProps,
            ~pathParams,
            ~queryParams,
          ),
          prepare: (
            ~environment: RescriptRelay.Environment.t,
            ~pathParams: dict<string>,
            ~queryParams: RelayRouter.Bindings.QueryParams.t,
            ~location: RelayRouter.History.location,
            ~intent: RelayRouter.Types.prepareIntent,
          ) => prepareRoute(
            ~environment,
            ~pathParams,
            ~queryParams,
            ~location,
            ~getPrepared,
            ~loadRouteRenderer,
            ~makePrepareProps,
            ~makeRouteKey=(
        ~pathParams: dict<string>,
        ~queryParams: RelayRouter.Bindings.QueryParams.t
      ): string => {
        ignore(pathParams)
      
        "Root__Todos:"
      
          ++ queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("statuses")->Option.getOr("")
          ++ queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("statusWithDefault")->Option.getOr("")
          ++ queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("byValue")->Option.getOr("")
      }
      
      ,
            ~routeName,
            ~intent
          ),
          children: [      {
              let routeName = "Root__Todos__ByStatus"
              let loadRouteRenderer = () => (() => import(Root__Todos__ByStatus_route_renderer.renderer))->Obj.magic->doLoadRouteRenderer(~routeName, ~loadedRouteRenderers)
              let makePrepareProps = (. 
              ~environment: RescriptRelay.Environment.t,
              ~pathParams: dict<string>,
              ~queryParams: RelayRouter.Bindings.QueryParams.t,
              ~location: RelayRouter.History.location,
            ): prepareProps => {
              let prepareProps: Route__Root__Todos__ByStatus_route.Internal.prepareProps =   {
                environment: environment,
            
                location: location,
                byStatus: pathParams->Dict.getUnsafe("byStatus")->Obj.magic,
                statuses: {
                  let param = queryParams->RelayRouter.Bindings.QueryParams.getArrayParamByKey("statuses")
                  React.useMemo(() => param->Option.map(value => value->Array.filterMap(value => value->TodoStatus.parse)), [param])
                },
                statusWithDefault: {
                  let param = queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("statusWithDefault")
                  React.useMemo(() => param->Option.flatMap(value => value->TodoStatus.parse)->Option.getOr(TodoStatus.defaultValue), [param])
                },
                byValue: {
                  let param = queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("byValue")
                  React.useMemo(() => param->Option.flatMap(value => Some(value)), [param])
                },
              }
              prepareProps->unsafe_toPrepareProps
            }
            
              {
                path: ":byStatus(completed|not-completed)",
                name: routeName,
                chunk: "Root__Todos__ByStatus_route_renderer",
                loadRouteRenderer,
                preloadCode: (
                  ~environment: RescriptRelay.Environment.t,
                  ~pathParams: dict<string>,
                  ~queryParams: RelayRouter.Bindings.QueryParams.t,
                  ~location: RelayRouter.History.location,
                ) => preloadCode(
                  ~loadedRouteRenderers,
                  ~routeName,
                  ~loadRouteRenderer,
                  ~environment,
                  ~location,
                  ~makePrepareProps,
                  ~pathParams,
                  ~queryParams,
                ),
                prepare: (
                  ~environment: RescriptRelay.Environment.t,
                  ~pathParams: dict<string>,
                  ~queryParams: RelayRouter.Bindings.QueryParams.t,
                  ~location: RelayRouter.History.location,
                  ~intent: RelayRouter.Types.prepareIntent,
                ) => prepareRoute(
                  ~environment,
                  ~pathParams,
                  ~queryParams,
                  ~location,
                  ~getPrepared,
                  ~loadRouteRenderer,
                  ~makePrepareProps,
                  ~makeRouteKey=(
              ~pathParams: dict<string>,
              ~queryParams: RelayRouter.Bindings.QueryParams.t
            ): string => {
            
              "Root__Todos__ByStatus:"
                ++ pathParams->Dict.get("byStatus")->Option.getOr("")
                ++ queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("statuses")->Option.getOr("")
                ++ queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("statusWithDefault")->Option.getOr("")
                ++ queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("byValue")->Option.getOr("")
            }
            
            ,
                  ~routeName,
                  ~intent
                ),
                children: [],
              }
            },
            {
              let routeName = "Root__Todos__ByStatusDecoded"
              let loadRouteRenderer = () => (() => import(Root__Todos__ByStatusDecoded_route_renderer.renderer))->Obj.magic->doLoadRouteRenderer(~routeName, ~loadedRouteRenderers)
              let makePrepareProps = (. 
              ~environment: RescriptRelay.Environment.t,
              ~pathParams: dict<string>,
              ~queryParams: RelayRouter.Bindings.QueryParams.t,
              ~location: RelayRouter.History.location,
            ): prepareProps => {
              let prepareProps: Route__Root__Todos__ByStatusDecoded_route.Internal.prepareProps =   {
                environment: environment,
            
                location: location,
                childParams: Obj.magic(pathParams),
                byStatusDecoded: pathParams->Dict.getUnsafe("byStatusDecoded")->((byStatusDecodedRawAsString: string) => (byStatusDecodedRawAsString :> TodoStatusPathParam.t)),
                statuses: {
                  let param = queryParams->RelayRouter.Bindings.QueryParams.getArrayParamByKey("statuses")
                  React.useMemo(() => param->Option.map(value => value->Array.filterMap(value => value->TodoStatus.parse)), [param])
                },
                statusWithDefault: {
                  let param = queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("statusWithDefault")
                  React.useMemo(() => param->Option.flatMap(value => value->TodoStatus.parse)->Option.getOr(TodoStatus.defaultValue), [param])
                },
                byValue: {
                  let param = queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("byValue")
                  React.useMemo(() => param->Option.flatMap(value => Some(value)), [param])
                },
              }
              prepareProps->unsafe_toPrepareProps
            }
            
              {
                path: ":byStatusDecoded",
                name: routeName,
                chunk: "Root__Todos__ByStatusDecoded_route_renderer",
                loadRouteRenderer,
                preloadCode: (
                  ~environment: RescriptRelay.Environment.t,
                  ~pathParams: dict<string>,
                  ~queryParams: RelayRouter.Bindings.QueryParams.t,
                  ~location: RelayRouter.History.location,
                ) => preloadCode(
                  ~loadedRouteRenderers,
                  ~routeName,
                  ~loadRouteRenderer,
                  ~environment,
                  ~location,
                  ~makePrepareProps,
                  ~pathParams,
                  ~queryParams,
                ),
                prepare: (
                  ~environment: RescriptRelay.Environment.t,
                  ~pathParams: dict<string>,
                  ~queryParams: RelayRouter.Bindings.QueryParams.t,
                  ~location: RelayRouter.History.location,
                  ~intent: RelayRouter.Types.prepareIntent,
                ) => prepareRoute(
                  ~environment,
                  ~pathParams,
                  ~queryParams,
                  ~location,
                  ~getPrepared,
                  ~loadRouteRenderer,
                  ~makePrepareProps,
                  ~makeRouteKey=(
              ~pathParams: dict<string>,
              ~queryParams: RelayRouter.Bindings.QueryParams.t
            ): string => {
            
              "Root__Todos__ByStatusDecoded:"
                ++ pathParams->Dict.get("byStatusDecoded")->Option.getOr("")
                ++ queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("statuses")->Option.getOr("")
                ++ queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("statusWithDefault")->Option.getOr("")
                ++ queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("byValue")->Option.getOr("")
            }
            
            ,
                  ~routeName,
                  ~intent
                ),
                children: [        {
                      let routeName = "Root__Todos__ByStatusDecoded__Child"
                      let loadRouteRenderer = () => (() => import(Root__Todos__ByStatusDecoded__Child_route_renderer.renderer))->Obj.magic->doLoadRouteRenderer(~routeName, ~loadedRouteRenderers)
                      let makePrepareProps = (. 
                      ~environment: RescriptRelay.Environment.t,
                      ~pathParams: dict<string>,
                      ~queryParams: RelayRouter.Bindings.QueryParams.t,
                      ~location: RelayRouter.History.location,
                    ): prepareProps => {
                      let prepareProps: Route__Root__Todos__ByStatusDecoded__Child_route.Internal.prepareProps =   {
                        environment: environment,
                    
                        location: location,
                        byStatusDecoded: pathParams->Dict.getUnsafe("byStatusDecoded")->((byStatusDecodedRawAsString: string) => (byStatusDecodedRawAsString :> TodoStatusPathParam.t)),
                        statuses: {
                          let param = queryParams->RelayRouter.Bindings.QueryParams.getArrayParamByKey("statuses")
                          React.useMemo(() => param->Option.map(value => value->Array.filterMap(value => value->TodoStatus.parse)), [param])
                        },
                        statusWithDefault: {
                          let param = queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("statusWithDefault")
                          React.useMemo(() => param->Option.flatMap(value => value->TodoStatus.parse)->Option.getOr(TodoStatus.defaultValue), [param])
                        },
                        byValue: {
                          let param = queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("byValue")
                          React.useMemo(() => param->Option.flatMap(value => Some(value)), [param])
                        },
                      }
                      prepareProps->unsafe_toPrepareProps
                    }
                    
                      {
                        path: "",
                        name: routeName,
                        chunk: "Root__Todos__ByStatusDecoded__Child_route_renderer",
                        loadRouteRenderer,
                        preloadCode: (
                          ~environment: RescriptRelay.Environment.t,
                          ~pathParams: dict<string>,
                          ~queryParams: RelayRouter.Bindings.QueryParams.t,
                          ~location: RelayRouter.History.location,
                        ) => preloadCode(
                          ~loadedRouteRenderers,
                          ~routeName,
                          ~loadRouteRenderer,
                          ~environment,
                          ~location,
                          ~makePrepareProps,
                          ~pathParams,
                          ~queryParams,
                        ),
                        prepare: (
                          ~environment: RescriptRelay.Environment.t,
                          ~pathParams: dict<string>,
                          ~queryParams: RelayRouter.Bindings.QueryParams.t,
                          ~location: RelayRouter.History.location,
                          ~intent: RelayRouter.Types.prepareIntent,
                        ) => prepareRoute(
                          ~environment,
                          ~pathParams,
                          ~queryParams,
                          ~location,
                          ~getPrepared,
                          ~loadRouteRenderer,
                          ~makePrepareProps,
                          ~makeRouteKey=(
                      ~pathParams: dict<string>,
                      ~queryParams: RelayRouter.Bindings.QueryParams.t
                    ): string => {
                    
                      "Root__Todos__ByStatusDecoded__Child:"
                        ++ pathParams->Dict.get("byStatusDecoded")->Option.getOr("")
                        ++ queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("statuses")->Option.getOr("")
                        ++ queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("statusWithDefault")->Option.getOr("")
                        ++ queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("byValue")->Option.getOr("")
                    }
                    
                    ,
                          ~routeName,
                          ~intent
                        ),
                        children: [],
                      }
                    }],
              }
            },
            {
              let routeName = "Root__Todos__ByStatusDecodedExtra"
              let loadRouteRenderer = () => (() => import(Root__Todos__ByStatusDecodedExtra_route_renderer.renderer))->Obj.magic->doLoadRouteRenderer(~routeName, ~loadedRouteRenderers)
              let makePrepareProps = (. 
              ~environment: RescriptRelay.Environment.t,
              ~pathParams: dict<string>,
              ~queryParams: RelayRouter.Bindings.QueryParams.t,
              ~location: RelayRouter.History.location,
            ): prepareProps => {
              let prepareProps: Route__Root__Todos__ByStatusDecodedExtra_route.Internal.prepareProps =   {
                environment: environment,
            
                location: location,
                byStatusDecoded: pathParams->Dict.getUnsafe("byStatusDecoded")->((byStatusDecodedRawAsString: string) => (byStatusDecodedRawAsString :> TodoStatusPathParam.t)),
                statuses: {
                  let param = queryParams->RelayRouter.Bindings.QueryParams.getArrayParamByKey("statuses")
                  React.useMemo(() => param->Option.map(value => value->Array.filterMap(value => value->TodoStatus.parse)), [param])
                },
                statusWithDefault: {
                  let param = queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("statusWithDefault")
                  React.useMemo(() => param->Option.flatMap(value => value->TodoStatus.parse)->Option.getOr(TodoStatus.defaultValue), [param])
                },
                byValue: {
                  let param = queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("byValue")
                  React.useMemo(() => param->Option.flatMap(value => Some(value)), [param])
                },
              }
              prepareProps->unsafe_toPrepareProps
            }
            
              {
                path: "extra/:byStatusDecoded",
                name: routeName,
                chunk: "Root__Todos__ByStatusDecodedExtra_route_renderer",
                loadRouteRenderer,
                preloadCode: (
                  ~environment: RescriptRelay.Environment.t,
                  ~pathParams: dict<string>,
                  ~queryParams: RelayRouter.Bindings.QueryParams.t,
                  ~location: RelayRouter.History.location,
                ) => preloadCode(
                  ~loadedRouteRenderers,
                  ~routeName,
                  ~loadRouteRenderer,
                  ~environment,
                  ~location,
                  ~makePrepareProps,
                  ~pathParams,
                  ~queryParams,
                ),
                prepare: (
                  ~environment: RescriptRelay.Environment.t,
                  ~pathParams: dict<string>,
                  ~queryParams: RelayRouter.Bindings.QueryParams.t,
                  ~location: RelayRouter.History.location,
                  ~intent: RelayRouter.Types.prepareIntent,
                ) => prepareRoute(
                  ~environment,
                  ~pathParams,
                  ~queryParams,
                  ~location,
                  ~getPrepared,
                  ~loadRouteRenderer,
                  ~makePrepareProps,
                  ~makeRouteKey=(
              ~pathParams: dict<string>,
              ~queryParams: RelayRouter.Bindings.QueryParams.t
            ): string => {
            
              "Root__Todos__ByStatusDecodedExtra:"
                ++ pathParams->Dict.get("byStatusDecoded")->Option.getOr("")
                ++ queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("statuses")->Option.getOr("")
                ++ queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("statusWithDefault")->Option.getOr("")
                ++ queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("byValue")->Option.getOr("")
            }
            
            ,
                  ~routeName,
                  ~intent
                ),
                children: [],
              }
            },
            {
              let routeName = "Root__Todos__Single"
              let loadRouteRenderer = () => (() => import(Root__Todos__Single_route_renderer.renderer))->Obj.magic->doLoadRouteRenderer(~routeName, ~loadedRouteRenderers)
              let makePrepareProps = (. 
              ~environment: RescriptRelay.Environment.t,
              ~pathParams: dict<string>,
              ~queryParams: RelayRouter.Bindings.QueryParams.t,
              ~location: RelayRouter.History.location,
            ): prepareProps => {
              let prepareProps: Route__Root__Todos__Single_route.Internal.prepareProps =   {
                environment: environment,
            
                location: location,
                todoId: pathParams->Dict.getUnsafe("todoId"),
                statuses: {
                  let param = queryParams->RelayRouter.Bindings.QueryParams.getArrayParamByKey("statuses")
                  React.useMemo(() => param->Option.map(value => value->Array.filterMap(value => value->TodoStatus.parse)), [param])
                },
                statusWithDefault: {
                  let param = queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("statusWithDefault")
                  React.useMemo(() => param->Option.flatMap(value => value->TodoStatus.parse)->Option.getOr(TodoStatus.defaultValue), [param])
                },
                byValue: {
                  let param = queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("byValue")
                  React.useMemo(() => param->Option.flatMap(value => Some(value)), [param])
                },
                showMore: {
                  let param = queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("showMore")
                  React.useMemo(() => param->Option.flatMap(value => switch value {
                  | "true" => Some(true)
                  | "false" => Some(false)
                  | _ => None
                  }), [param])
                },
              }
              prepareProps->unsafe_toPrepareProps
            }
            
              {
                path: ":todoId",
                name: routeName,
                chunk: "Root__Todos__Single_route_renderer",
                loadRouteRenderer,
                preloadCode: (
                  ~environment: RescriptRelay.Environment.t,
                  ~pathParams: dict<string>,
                  ~queryParams: RelayRouter.Bindings.QueryParams.t,
                  ~location: RelayRouter.History.location,
                ) => preloadCode(
                  ~loadedRouteRenderers,
                  ~routeName,
                  ~loadRouteRenderer,
                  ~environment,
                  ~location,
                  ~makePrepareProps,
                  ~pathParams,
                  ~queryParams,
                ),
                prepare: (
                  ~environment: RescriptRelay.Environment.t,
                  ~pathParams: dict<string>,
                  ~queryParams: RelayRouter.Bindings.QueryParams.t,
                  ~location: RelayRouter.History.location,
                  ~intent: RelayRouter.Types.prepareIntent,
                ) => prepareRoute(
                  ~environment,
                  ~pathParams,
                  ~queryParams,
                  ~location,
                  ~getPrepared,
                  ~loadRouteRenderer,
                  ~makePrepareProps,
                  ~makeRouteKey=(
              ~pathParams: dict<string>,
              ~queryParams: RelayRouter.Bindings.QueryParams.t
            ): string => {
            
              "Root__Todos__Single:"
                ++ pathParams->Dict.get("todoId")->Option.getOr("")
                ++ queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("statuses")->Option.getOr("")
                ++ queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("statusWithDefault")->Option.getOr("")
                ++ queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("byValue")->Option.getOr("")
                ++ queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("showMore")->Option.getOr("")
            }
            
            ,
                  ~routeName,
                  ~intent
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