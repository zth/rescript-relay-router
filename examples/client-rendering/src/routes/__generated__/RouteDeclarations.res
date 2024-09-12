
open RelayRouter__Internal__DeclarationsSupport

external unsafe_toPrepareProps: 'any => prepareProps = "%identity"

let loadedRouteRenderers: Belt.HashMap.String.t<loadedRouteRenderer> = Belt.HashMap.String.make(
  ~hintSize=7,
)

let make = (~prepareDisposeTimeout=5 * 60 * 1000): array<RelayRouter.Types.route> => {
  let {prepareRoute, getPrepared} = makePrepareAssets(~loadedRouteRenderers, ~prepareDisposeTimeout)

  [
      {
    let routeName = "Root"
    let loadRouteRenderer = () => (() => Js.import(Root_route_renderer.renderer))->Obj.magic->doLoadRouteRenderer(~routeName, ~loadedRouteRenderers)
    let makePrepareProps = (. 
    ~environment: RescriptRelay.Environment.t,
    ~pathParams: Js.Dict.t<string>,
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
        ~pathParams: Js.Dict.t<string>,
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
        ~pathParams: Js.Dict.t<string>,
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
    ~pathParams: Js.Dict.t<string>,
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
        let loadRouteRenderer = () => (() => Js.import(Root__Todos_route_renderer.renderer))->Obj.magic->doLoadRouteRenderer(~routeName, ~loadedRouteRenderers)
        let makePrepareProps = (. 
        ~environment: RescriptRelay.Environment.t,
        ~pathParams: Js.Dict.t<string>,
        ~queryParams: RelayRouter.Bindings.QueryParams.t,
        ~location: RelayRouter.History.location,
      ): prepareProps => {
        let prepareProps: Route__Root__Todos_route.Internal.prepareProps =   {
          environment: environment,
      
          location: location,
          childParams: Obj.magic(pathParams),
          statuses: queryParams->RelayRouter.Bindings.QueryParams.getArrayParamByKey("statuses")->Belt.Option.map(value => value->Belt.Array.keepMap(value => value->Js.Global.decodeURIComponent->TodoStatus.parse)),
          statusWithDefault: queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("statusWithDefault")->Belt.Option.flatMap(value => value->Js.Global.decodeURIComponent->TodoStatus.parse)->Belt.Option.getWithDefault(TodoStatus.defaultValue),
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
            ~pathParams: Js.Dict.t<string>,
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
            ~pathParams: Js.Dict.t<string>,
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
        ~pathParams: Js.Dict.t<string>,
        ~queryParams: RelayRouter.Bindings.QueryParams.t
      ): string => {
        ignore(pathParams)
      
        "Root__Todos:"
      
          ++ queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("statuses")->Option.getOr("")
          ++ queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("statusWithDefault")->Option.getOr("")
      }
      
      ,
            ~routeName,
            ~intent
          ),
          children: [      {
              let routeName = "Root__Todos__ByStatus"
              let loadRouteRenderer = () => (() => Js.import(Root__Todos__ByStatus_route_renderer.renderer))->Obj.magic->doLoadRouteRenderer(~routeName, ~loadedRouteRenderers)
              let makePrepareProps = (. 
              ~environment: RescriptRelay.Environment.t,
              ~pathParams: Js.Dict.t<string>,
              ~queryParams: RelayRouter.Bindings.QueryParams.t,
              ~location: RelayRouter.History.location,
            ): prepareProps => {
              let prepareProps: Route__Root__Todos__ByStatus_route.Internal.prepareProps =   {
                environment: environment,
            
                location: location,
                byStatus: pathParams->Js.Dict.unsafeGet("byStatus")->Obj.magic,
                statuses: queryParams->RelayRouter.Bindings.QueryParams.getArrayParamByKey("statuses")->Belt.Option.map(value => value->Belt.Array.keepMap(value => value->Js.Global.decodeURIComponent->TodoStatus.parse)),
                statusWithDefault: queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("statusWithDefault")->Belt.Option.flatMap(value => value->Js.Global.decodeURIComponent->TodoStatus.parse)->Belt.Option.getWithDefault(TodoStatus.defaultValue),
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
                  ~pathParams: Js.Dict.t<string>,
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
                  ~pathParams: Js.Dict.t<string>,
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
              ~pathParams: Js.Dict.t<string>,
              ~queryParams: RelayRouter.Bindings.QueryParams.t
            ): string => {
            
              "Root__Todos__ByStatus:"
                ++ pathParams->Js.Dict.get("byStatus")->Option.getOr("")
                ++ queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("statuses")->Option.getOr("")
                ++ queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("statusWithDefault")->Option.getOr("")
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
              let loadRouteRenderer = () => (() => Js.import(Root__Todos__ByStatusDecoded_route_renderer.renderer))->Obj.magic->doLoadRouteRenderer(~routeName, ~loadedRouteRenderers)
              let makePrepareProps = (. 
              ~environment: RescriptRelay.Environment.t,
              ~pathParams: Js.Dict.t<string>,
              ~queryParams: RelayRouter.Bindings.QueryParams.t,
              ~location: RelayRouter.History.location,
            ): prepareProps => {
              let prepareProps: Route__Root__Todos__ByStatusDecoded_route.Internal.prepareProps =   {
                environment: environment,
            
                location: location,
                childParams: Obj.magic(pathParams),
                byStatusDecoded: pathParams->Js.Dict.unsafeGet("byStatusDecoded")->((byStatusDecodedRawAsString: string) => (byStatusDecodedRawAsString :> TodoStatusPathParam.t)),
                statuses: queryParams->RelayRouter.Bindings.QueryParams.getArrayParamByKey("statuses")->Belt.Option.map(value => value->Belt.Array.keepMap(value => value->Js.Global.decodeURIComponent->TodoStatus.parse)),
                statusWithDefault: queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("statusWithDefault")->Belt.Option.flatMap(value => value->Js.Global.decodeURIComponent->TodoStatus.parse)->Belt.Option.getWithDefault(TodoStatus.defaultValue),
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
                  ~pathParams: Js.Dict.t<string>,
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
                  ~pathParams: Js.Dict.t<string>,
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
              ~pathParams: Js.Dict.t<string>,
              ~queryParams: RelayRouter.Bindings.QueryParams.t
            ): string => {
            
              "Root__Todos__ByStatusDecoded:"
                ++ pathParams->Js.Dict.get("byStatusDecoded")->Option.getOr("")
                ++ queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("statuses")->Option.getOr("")
                ++ queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("statusWithDefault")->Option.getOr("")
            }
            
            ,
                  ~routeName,
                  ~intent
                ),
                children: [        {
                      let routeName = "Root__Todos__ByStatusDecoded__Child"
                      let loadRouteRenderer = () => (() => Js.import(Root__Todos__ByStatusDecoded__Child_route_renderer.renderer))->Obj.magic->doLoadRouteRenderer(~routeName, ~loadedRouteRenderers)
                      let makePrepareProps = (. 
                      ~environment: RescriptRelay.Environment.t,
                      ~pathParams: Js.Dict.t<string>,
                      ~queryParams: RelayRouter.Bindings.QueryParams.t,
                      ~location: RelayRouter.History.location,
                    ): prepareProps => {
                      let prepareProps: Route__Root__Todos__ByStatusDecoded__Child_route.Internal.prepareProps =   {
                        environment: environment,
                    
                        location: location,
                        byStatusDecoded: pathParams->Js.Dict.unsafeGet("byStatusDecoded")->((byStatusDecodedRawAsString: string) => (byStatusDecodedRawAsString :> TodoStatusPathParam.t)),
                        statuses: queryParams->RelayRouter.Bindings.QueryParams.getArrayParamByKey("statuses")->Belt.Option.map(value => value->Belt.Array.keepMap(value => value->Js.Global.decodeURIComponent->TodoStatus.parse)),
                        statusWithDefault: queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("statusWithDefault")->Belt.Option.flatMap(value => value->Js.Global.decodeURIComponent->TodoStatus.parse)->Belt.Option.getWithDefault(TodoStatus.defaultValue),
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
                          ~pathParams: Js.Dict.t<string>,
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
                          ~pathParams: Js.Dict.t<string>,
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
                      ~pathParams: Js.Dict.t<string>,
                      ~queryParams: RelayRouter.Bindings.QueryParams.t
                    ): string => {
                    
                      "Root__Todos__ByStatusDecoded__Child:"
                        ++ pathParams->Js.Dict.get("byStatusDecoded")->Option.getOr("")
                        ++ queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("statuses")->Option.getOr("")
                        ++ queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("statusWithDefault")->Option.getOr("")
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
              let loadRouteRenderer = () => (() => Js.import(Root__Todos__ByStatusDecodedExtra_route_renderer.renderer))->Obj.magic->doLoadRouteRenderer(~routeName, ~loadedRouteRenderers)
              let makePrepareProps = (. 
              ~environment: RescriptRelay.Environment.t,
              ~pathParams: Js.Dict.t<string>,
              ~queryParams: RelayRouter.Bindings.QueryParams.t,
              ~location: RelayRouter.History.location,
            ): prepareProps => {
              let prepareProps: Route__Root__Todos__ByStatusDecodedExtra_route.Internal.prepareProps =   {
                environment: environment,
            
                location: location,
                byStatusDecoded: pathParams->Js.Dict.unsafeGet("byStatusDecoded")->((byStatusDecodedRawAsString: string) => (byStatusDecodedRawAsString :> TodoStatusPathParam.t)),
                statuses: queryParams->RelayRouter.Bindings.QueryParams.getArrayParamByKey("statuses")->Belt.Option.map(value => value->Belt.Array.keepMap(value => value->Js.Global.decodeURIComponent->TodoStatus.parse)),
                statusWithDefault: queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("statusWithDefault")->Belt.Option.flatMap(value => value->Js.Global.decodeURIComponent->TodoStatus.parse)->Belt.Option.getWithDefault(TodoStatus.defaultValue),
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
                  ~pathParams: Js.Dict.t<string>,
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
                  ~pathParams: Js.Dict.t<string>,
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
              ~pathParams: Js.Dict.t<string>,
              ~queryParams: RelayRouter.Bindings.QueryParams.t
            ): string => {
            
              "Root__Todos__ByStatusDecodedExtra:"
                ++ pathParams->Js.Dict.get("byStatusDecoded")->Option.getOr("")
                ++ queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("statuses")->Option.getOr("")
                ++ queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("statusWithDefault")->Option.getOr("")
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
              let loadRouteRenderer = () => (() => Js.import(Root__Todos__Single_route_renderer.renderer))->Obj.magic->doLoadRouteRenderer(~routeName, ~loadedRouteRenderers)
              let makePrepareProps = (. 
              ~environment: RescriptRelay.Environment.t,
              ~pathParams: Js.Dict.t<string>,
              ~queryParams: RelayRouter.Bindings.QueryParams.t,
              ~location: RelayRouter.History.location,
            ): prepareProps => {
              let prepareProps: Route__Root__Todos__Single_route.Internal.prepareProps =   {
                environment: environment,
            
                location: location,
                todoId: pathParams->Js.Dict.unsafeGet("todoId"),
                statuses: queryParams->RelayRouter.Bindings.QueryParams.getArrayParamByKey("statuses")->Belt.Option.map(value => value->Belt.Array.keepMap(value => value->Js.Global.decodeURIComponent->TodoStatus.parse)),
                statusWithDefault: queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("statusWithDefault")->Belt.Option.flatMap(value => value->Js.Global.decodeURIComponent->TodoStatus.parse)->Belt.Option.getWithDefault(TodoStatus.defaultValue),
                showMore: queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("showMore")->Belt.Option.flatMap(value => switch value {
                  | "true" => Some(true)
                  | "false" => Some(false)
                  | _ => None
                  }),
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
                  ~pathParams: Js.Dict.t<string>,
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
                  ~pathParams: Js.Dict.t<string>,
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
              ~pathParams: Js.Dict.t<string>,
              ~queryParams: RelayRouter.Bindings.QueryParams.t
            ): string => {
            
              "Root__Todos__Single:"
                ++ pathParams->Js.Dict.get("todoId")->Option.getOr("")
                ++ queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("statuses")->Option.getOr("")
                ++ queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("statusWithDefault")->Option.getOr("")
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