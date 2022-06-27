
open RelayRouter__Internal__DeclarationsSupport


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
        .
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
            .
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
                  .
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