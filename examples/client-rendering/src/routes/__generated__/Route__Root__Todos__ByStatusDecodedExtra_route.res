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
  }

}

@live
let useParseQueryParams = (search: string): queryParams => {
  open RelayRouter.Bindings
  let queryParams = React.useMemo(() => QueryParams.parse(search), [search])
  {
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
  let {search} = RelayRouter.Utils.useLocation()
  let currentQueryParams = React.useMemo(() => {
    search->useParseQueryParams
  }, [search])

  {
    queryParams: currentQueryParams,
    setParams: RelayRouter__Internal.useSetQueryParams(~useParseQueryParams, ~applyQueryParams),
  }
}

@inline
let routePattern = "/todos/extra/:byStatusDecoded"

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
let useMakeLinkWithPreservedPath = (): ((queryParams => queryParams) => string) => RelayRouter__Internal.useMakeLinkWithPreservedPath(~useParseQueryParams, ~applyQueryParams)


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