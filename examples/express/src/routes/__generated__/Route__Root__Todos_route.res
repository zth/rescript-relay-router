// @generated
// This file is autogenerated from `todoRoutes.json`, do not edit manually.
type queryParams = {
  statuses: option<array<TodoStatus.t>>,
}

module Internal = {

  let parseQueryParams = (queryParams: RelayRouter.Bindings.QueryParams.t): queryParams => {
    open RelayRouter.Bindings
    {
      statuses: queryParams->QueryParams.getArrayParamByKey("statuses")->Option.map(value => value->Array.filterMap(value => value->TodoStatus.parse)),
    }
  }

  @live
  type childPathParams = {
    byStatus: option<[#"completed" | #"notCompleted"]>,
    todoId: option<string>,
  }

  @live
  type prepareProps = {
    environment: RescriptRelay.Environment.t,
    location: RelayRouter.History.location,
    ...queryParams,
    childParams: childPathParams,
  }

  @live
  type renderProps<'prepared> = {
    childRoutes: React.element,
    prepared: 'prepared,
    environment: RescriptRelay.Environment.t,
    location: RelayRouter.History.location,
    ...queryParams,
    childParams: childPathParams,
  }

  @live
  type renderers<'prepared> = {
    prepare: prepareProps => 'prepared,
    prepareCode: option<(. prepareProps) => array<RelayRouter.Types.preloadAsset>>,
    render: renderProps<'prepared> => React.element,
  }
  @live
  let makePrepareProps = (. 
    ~environment: RescriptRelay.Environment.t,
    ~pathParams: dict<string>,
    ~queryParams: RelayRouter.Bindings.QueryParams.t,
    ~location: RelayRouter.History.location,
  ): prepareProps => {
    {
      environment: environment,
      location: location,
      childParams: Obj.magic(pathParams),
      statuses: queryParams->RelayRouter.Bindings.QueryParams.getArrayParamByKey("statuses")->Option.map(value => value->Array.filterMap(value => value->TodoStatus.parse)),
    }
  }

}

@live
let applyQueryParams = (
  queryParams: RelayRouter__Bindings.QueryParams.t,
  ~newParams: queryParams,
) => {
  open RelayRouter__Bindings

  
  queryParams->QueryParams.setParamArrayOpt(~key="statuses", ~value=newParams.statuses->Option.map(statuses => statuses->Array.map(statuses => statuses->TodoStatus.serialize)))
}

@live
type useQueryParamsReturn = {
  queryParams: queryParams,
  setParams: (
    ~setter: queryParams => queryParams,
    ~onAfterParamsSet: queryParams => unit=?,
    ~navigationMode_: RelayRouter.Types.setQueryParamsMode=?,
    ~removeNotControlledParams: bool=?,
    ~shallow: bool=?,
  ) => unit
}

@live
let useQueryParams = (): useQueryParamsReturn => {
  let {search: search__} = RelayRouter.Utils.useLocation()
  let queryParams__ = React.useMemo(() => RelayRouter.Bindings.QueryParams.parse(search__), [search__])
  let statuses = {
    let param = queryParams__->RelayRouter.Bindings.QueryParams.getArrayParamByKey("statuses")
    React.useMemo(() => param->Option.map(value => value->Array.filterMap(value => value->TodoStatus.parse)), [param->Option.getOr([])->Array.join(" | ")])
  }
  let currentQueryParams = React.useMemo(() => {
    statuses: statuses    
  }, [search__])

  {
    queryParams: currentQueryParams,
    setParams: RelayRouter__Internal.useSetQueryParams(~parseQueryParams=Internal.parseQueryParams, ~applyQueryParams),
  }
}

@inline
let routePattern = "/todos"

@live
let makeLink = (~statuses: option<array<TodoStatus.t>>=?) => {
  open RelayRouter.Bindings
  let queryParams = QueryParams.make()
  switch statuses {
    | None => ()
    | Some(statuses) => queryParams->QueryParams.setParamArray(~key="statuses", ~value=statuses->Array.map(value => value->TodoStatus.serialize))
  }
  RelayRouter.Bindings.generatePath(routePattern, Dict.fromArray([])) ++ queryParams->QueryParams.toString
}
@live
let makeLinkFromQueryParams = (queryParams: queryParams) => {
  makeLink(~statuses=?queryParams.statuses, )
}

@live
let useMakeLinkWithPreservedPath = (): ((queryParams => queryParams) => string) => RelayRouter__Internal.useMakeLinkWithPreservedPath(~parseQueryParams=Internal.parseQueryParams, ~applyQueryParams)


@live
let isRouteActive = (~exact: bool=false, {pathname}: RelayRouter.History.location): bool => {
  RelayRouter.Internal.matchPathWithOptions({"path": routePattern, "end": exact}, pathname)->Option.isSome
}

@live
let useIsRouteActive = (~exact=false) => {
  let location = RelayRouter.Utils.useLocation()
  React.useMemo(() => location->isRouteActive(~exact), (location, exact))
}
@live
type subRoute = [#ByStatus | #Single]

@live
let getActiveSubRoute = (location: RelayRouter.History.location): option<[#ByStatus | #Single]> => {
  let {pathname} = location
  if RelayRouter.Internal.matchPath("/todos/:byStatus(completed|notCompleted)", pathname)->Option.isSome {
      Some(#ByStatus)
    } else if RelayRouter.Internal.matchPath("/todos/:todoId", pathname)->Option.isSome {
      Some(#Single)
    } else {
    None
  }
}

@live
let useActiveSubRoute = (): option<[#ByStatus | #Single]> => {
  let location = RelayRouter.Utils.useLocation()
  React.useMemo(() => {
    getActiveSubRoute(location)
  }, [location])
}



@obj
external makeRenderer: (
  ~prepare: Internal.prepareProps => 'prepared,
  ~prepareCode: Internal.prepareProps => array<RelayRouter.Types.preloadAsset>=?,
  ~render: Internal.renderProps<'prepared> => React.element,
) => Internal.renderers<'prepared> = ""


@live 
let parseRoute: (
  string,
  ~exact: bool=?,
) => option<queryParams> = RelayRouter.Internal.parseRoute(
  QueryParams({
    routePattern,
    parseQueryParams: Internal.parseQueryParams,
  }),
)

