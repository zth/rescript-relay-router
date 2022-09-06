// @generated
// This file is autogenerated from `todoRoutes.json`, do not edit manually.
@inline
let routePattern = "/todos"

@live
let makeLink = () => {
  RelayRouter.Types.AppRoute({
    routePattern, 
    url: `/todos`
  })
}

@live
let isRouteActive = (~exact: bool=false, {pathname}: RelayRouter.History.location): bool => {
  RelayRouter.Internal.matchPathWithOptions({"path": routePattern, "end": exact}, pathname)->Belt.Option.isSome
}

@live
let useIsRouteActive = (~exact=false, ()) => {
  let location = RelayRouter.Utils.useLocation()
  React.useMemo2(() => location->isRouteActive(~exact), (location, exact))
}
@live
type subRoute = [#Single]

@live
let useActiveSubRoute = (): option<[#Single]> => {
  let location = RelayRouter.Utils.useLocation()
  React.useMemo1(() => {
    let {pathname} = location
    if RelayRouter.Internal.matchPath("/todos/:todoId", pathname)->Belt.Option.isSome {
      Some(#Single)
    } else {
      None
    }
  }, [location])
}

@live
type prepareProps = {
  environment: RescriptRelay.Environment.t,
  location: RelayRouter.History.location,
}

let makeRouteKey = (
  ~pathParams: Js.Dict.t<string>,
  ~queryParams: RelayRouter.Bindings.QueryParams.t
): string => {
  ignore(pathParams)
  ignore(queryParams)

  "Root__Todos:"


}

@live
let makePrepareProps = (. 
  ~environment: RescriptRelay.Environment.t,
  ~pathParams: Js.Dict.t<string>,
  ~queryParams: RelayRouter.Bindings.QueryParams.t,
  ~location: RelayRouter.History.location,
): prepareProps => {
  ignore(pathParams)
  ignore(queryParams)
  {
    environment: environment,

    location: location,
  }
}

@live
type renderProps<'prepared> = {
  childRoutes: React.element,
  prepared: 'prepared,
  environment: RescriptRelay.Environment.t,
  location: RelayRouter.History.location,
}

@live
type renderers<'prepared> = {
  prepare: prepareProps => 'prepared,
  prepareCode: option<(. prepareProps) => array<RelayRouter.Types.preloadAsset>>,
  render: renderProps<'prepared> => React.element,
}

@obj
external makeRenderer: (
  ~prepare: prepareProps => 'prepared,
  ~prepareCode: prepareProps => array<RelayRouter.Types.preloadAsset>=?,
  ~render: renderProps<'prepared> => React.element,
  unit
) => renderers<'prepared> = ""

