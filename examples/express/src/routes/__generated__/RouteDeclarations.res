
open RelayRouter__Internal__DeclarationsSupport

external unsafe_toPrepareProps: 'any => prepareProps = "%identity"


@val external import__Root: (@as(json`"@rescriptModule/Root_route_renderer"`) _, unit) => Js.Promise.t<RouteRenderer.t> = "import"

@val external import__Root__Todos: (@as(json`"@rescriptModule/Root__Todos_route_renderer"`) _, unit) => Js.Promise.t<RouteRenderer.t> = "import"

@val external import__Root__Todos__Single: (@as(json`"@rescriptModule/Root__Todos__Single_route_renderer"`) _, unit) => Js.Promise.t<RouteRenderer.t> = "import"

let loadedRouteRenderers: Belt.HashMap.String.t<loadedRouteRenderer> = Belt.HashMap.String.make(
  ~hintSize=3,
)

let make = (~prepareDisposeTimeout=5 * 60 * 1000, ()): array<RelayRouter.Types.route> => {
  let {prepareRoute, getPrepared} = makePrepareAssets(~loadedRouteRenderers, ~prepareDisposeTimeout)

  [
      {
    let routeName = "Root"
    let loadRouteRenderer = () => import__Root->doLoadRouteRenderer(~routeName, ~loadedRouteRenderers)
    let makePrepareProps = (. 
    ~environment: RescriptRelay.Environment.t,
    ~pathParams: Js.Dict.t<string>,
    ~queryParams: RelayRouter.Bindings.QueryParams.t,
    ~location: RelayRouter.History.location,
  ): prepareProps => {
    ignore(pathParams)
    ignore(queryParams)
    let prepareProps: Route__Root_route.prepareProps =   {
      environment: environment,
  
      location: location,
    }
    prepareProps->unsafe_toPrepareProps
  }
  
    {
      path: "/",
      name: routeName,
      chunk: "Root_route_renderer",
      loadRouteRenderer,
      preloadCode: (
        . ~environment: RescriptRelay.Environment.t,
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
        . ~environment: RescriptRelay.Environment.t,
        ~pathParams: Js.Dict.t<string>,
        ~queryParams: RelayRouter.Bindings.QueryParams.t,
        ~location: RelayRouter.History.location,
        ~intent: RelayRouter.Types.prepareIntent,
      ) => prepareRoute(
        .
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
        let loadRouteRenderer = () => import__Root__Todos->doLoadRouteRenderer(~routeName, ~loadedRouteRenderers)
        let makePrepareProps = (. 
        ~environment: RescriptRelay.Environment.t,
        ~pathParams: Js.Dict.t<string>,
        ~queryParams: RelayRouter.Bindings.QueryParams.t,
        ~location: RelayRouter.History.location,
      ): prepareProps => {
        ignore(pathParams)
        ignore(queryParams)
        let prepareProps: Route__Root__Todos_route.prepareProps =   {
          environment: environment,
      
          location: location,
        }
        prepareProps->unsafe_toPrepareProps
      }
      
        {
          path: "todos",
          name: routeName,
          chunk: "Root__Todos_route_renderer",
          loadRouteRenderer,
          preloadCode: (
            . ~environment: RescriptRelay.Environment.t,
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
            . ~environment: RescriptRelay.Environment.t,
            ~pathParams: Js.Dict.t<string>,
            ~queryParams: RelayRouter.Bindings.QueryParams.t,
            ~location: RelayRouter.History.location,
            ~intent: RelayRouter.Types.prepareIntent,
          ) => prepareRoute(
            .
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
      
        "Root__Todos:"
      
      
      }
      
      ,
            ~routeName,
            ~intent
          ),
          children: [      {
              let routeName = "Root__Todos__Single"
              let loadRouteRenderer = () => import__Root__Todos__Single->doLoadRouteRenderer(~routeName, ~loadedRouteRenderers)
              let makePrepareProps = (. 
              ~environment: RescriptRelay.Environment.t,
              ~pathParams: Js.Dict.t<string>,
              ~queryParams: RelayRouter.Bindings.QueryParams.t,
              ~location: RelayRouter.History.location,
            ): prepareProps => {
              let prepareProps: Route__Root__Todos__Single_route.prepareProps =   {
                environment: environment,
            
                location: location,
                todoId: pathParams->Js.Dict.unsafeGet("todoId"),
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
                  . ~environment: RescriptRelay.Environment.t,
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
                  . ~environment: RescriptRelay.Environment.t,
                  ~pathParams: Js.Dict.t<string>,
                  ~queryParams: RelayRouter.Bindings.QueryParams.t,
                  ~location: RelayRouter.History.location,
                  ~intent: RelayRouter.Types.prepareIntent,
                ) => prepareRoute(
                  .
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
                ++ pathParams->Js.Dict.get("todoId")->Belt.Option.getWithDefault("")
                ++ queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("showMore")->Belt.Option.getWithDefault("")
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