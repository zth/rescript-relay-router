// @generated
// This file is autogenerated from `todoRoutes.json`, do not edit manually.
@live
type pathParams = {
  byStatusDecoded: TodoStatusPathParam.t,
}

type queryParams = {
  statuses: option<array<TodoStatus.t>>,
  statusWithDefault: TodoStatus.t,
  byValue: option<string>,
}

module Internal = {

  let parseQueryParams = (queryParams: RelayRouter.Bindings.QueryParams.t): queryParams => {
    open RelayRouter.Bindings
    {
      statuses: queryParams->QueryParams.getArrayParamByKey("statuses")->Option.map(value => value->Array.filterMap(value => value->TodoStatus.parse)),
      statusWithDefault: queryParams->QueryParams.getParamByKey("statusWithDefault")->Option.flatMap(value => value->TodoStatus.parse)->Option.getOr(TodoStatus.defaultValue),
      byValue: queryParams->QueryParams.getParamByKey("byValue")->Option.flatMap(value => Some(value)),
    }
  }

  @live
  type prepareProps = {
    environment: RescriptRelay.Environment.t,
    location: RelayRouter.History.location,
    ...pathParams,
    ...queryParams,
  }

  @live
  type renderProps<'prepared> = {
    childRoutes: React.element,
    prepared: 'prepared,
    environment: RescriptRelay.Environment.t,
    location: RelayRouter.History.location,
    ...pathParams,
    ...queryParams,
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
      byStatusDecoded: pathParams->Dict.getUnsafe("byStatusDecoded")->((byStatusDecodedRawAsString: string) => (byStatusDecodedRawAsString :> TodoStatusPathParam.t)),
      statuses: queryParams->RelayRouter.Bindings.QueryParams.getArrayParamByKey("statuses")->Option.map(value => value->Array.filterMap(value => value->TodoStatus.parse)),
      statusWithDefault: queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("statusWithDefault")->Option.flatMap(value => value->TodoStatus.parse)->Option.getOr(TodoStatus.defaultValue),
      byValue: queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("byValue")->Option.flatMap(value => Some(value)),
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
  queryParams->QueryParams.setParamOpt(~key="statusWithDefault", ~value=newParams.statusWithDefault->TodoStatus.serialize === TodoStatus.defaultValue->TodoStatus.serialize ? None : newParams.statusWithDefault->TodoStatus.serialize->Some)
  queryParams->QueryParams.setParamOpt(~key="byValue", ~value=newParams.byValue->Option.map(byValue => byValue))
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
  let statusWithDefault = {
    let param = queryParams__->RelayRouter.Bindings.QueryParams.getParamByKey("statusWithDefault")
    React.useMemo(() => param->Option.flatMap(value => value->TodoStatus.parse)->Option.getOr(TodoStatus.defaultValue), [param])
  }
  let byValue = {
    let param = queryParams__->RelayRouter.Bindings.QueryParams.getParamByKey("byValue")
    React.useMemo(() => param->Option.flatMap(value => Some(value)), [param])
  }
  let currentQueryParams = React.useMemo(() => {
    statuses: statuses,
    statusWithDefault: statusWithDefault,
    byValue: byValue    
  }, [search__])

  {
    queryParams: currentQueryParams,
    setParams: RelayRouter__Internal.useSetQueryParams(~parseQueryParams=Internal.parseQueryParams, ~applyQueryParams),
  }
}

@inline
let routePattern = "/todos/:byStatusDecoded"

@live
let makeLink = (~byStatusDecoded: TodoStatusPathParam.t, ~statuses: option<array<TodoStatus.t>>=?, ~statusWithDefault: option<TodoStatus.t>=?, ~byValue: option<string>=?) => {
  open RelayRouter.Bindings
  let queryParams = QueryParams.make()
  switch statuses {
    | None => ()
    | Some(statuses) => queryParams->QueryParams.setParamArray(~key="statuses", ~value=statuses->Array.map(value => value->TodoStatus.serialize))
  }

  switch statusWithDefault {
    | None => ()
    | Some(statusWithDefault) => queryParams->QueryParams.setParamOpt(~key="statusWithDefault", ~value=statusWithDefault->TodoStatus.serialize === TodoStatus.defaultValue->TodoStatus.serialize ? None : statusWithDefault->TodoStatus.serialize->Some)
  }

  switch byValue {
    | None => ()
    | Some(byValue) => queryParams->QueryParams.setParam(~key="byValue", ~value=byValue)
  }
  RelayRouter.Bindings.generatePath(routePattern, Dict.fromArray([("byStatusDecoded", (byStatusDecoded :> string)->encodeURIComponent)])) ++ queryParams->QueryParams.toString
}
@live
let makeLinkFromQueryParams = (~byStatusDecoded: TodoStatusPathParam.t, queryParams: queryParams) => {
  makeLink(~byStatusDecoded, ~statuses=?queryParams.statuses, ~statusWithDefault=queryParams.statusWithDefault, ~byValue=?queryParams.byValue, )
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
let usePathParams = (): option<pathParams> => {
  let {pathname} = RelayRouter.Utils.useLocation()
  switch RelayRouter.Internal.matchPath(routePattern, pathname) {
  | Some({params}) => Some(Obj.magic(params))
  | None => None
  }
}

@obj
external makeRenderer: (
  ~prepare: Internal.prepareProps => 'prepared,
  ~prepareCode: Internal.prepareProps => array<RelayRouter.Types.preloadAsset>=?,
  ~render: Internal.renderProps<'prepared> => React.element,
) => Internal.renderers<'prepared> = ""


@live 
let parseRoute = (route: string, ~exact=false): option<(
  pathParams,
  queryParams,
)> => {
  switch route->String.split("?") {
  | [pathName, search] =>
    RelayRouter.Internal.matchPathWithOptions(
      {"path": routePattern, "end": exact},
      pathName,
    )->Option.map(({params}) => {
      let params: pathParams = Obj.magic(params)
      let queryParams =
        search
        ->RelayRouter.Bindings.QueryParams.parse
        ->Internal.parseQueryParams
      (params, queryParams)
    })
  | _ => None
  }
}

