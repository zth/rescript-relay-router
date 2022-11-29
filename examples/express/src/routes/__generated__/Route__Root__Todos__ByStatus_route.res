// @generated
// This file is autogenerated from `todoRoutes.json`, do not edit manually.
module Internal = {
  @live
  type prepareProps = {
    environment: RescriptRelay.Environment.t,
    location: RelayRouter.History.location,
    byStatus: [#completed | #notCompleted],
    statuses: option<array<TodoStatus.t>>,
  }

  @live
  type renderProps<'prepared> = {
    childRoutes: React.element,
    prepared: 'prepared,
    environment: RescriptRelay.Environment.t,
    location: RelayRouter.History.location,
    byStatus: [#completed | #notCompleted],
    statuses: option<array<TodoStatus.t>>,
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
    ~pathParams: Js.Dict.t<string>,
    ~queryParams: RelayRouter.Bindings.QueryParams.t,
    ~location: RelayRouter.History.location,
  ): prepareProps => {
    {
      environment: environment,
  
      location: location,
      byStatus: pathParams->Js.Dict.unsafeGet("byStatus")->Obj.magic,
      statuses: queryParams->RelayRouter.Bindings.QueryParams.getArrayParamByKey("statuses")->Belt.Option.map(value => value->Belt.Array.keepMap(value => value->Js.Global.decodeURIComponent->TodoStatus.parse)),
    }
  }

}

type queryParams = {
  statuses: option<array<TodoStatus.t>>,
}

@live
let parseQueryParams = (search: string): queryParams => {
  open RelayRouter.Bindings
  let queryParams = QueryParams.parse(search)
  {
    statuses: queryParams->QueryParams.getArrayParamByKey("statuses")->Belt.Option.map(value => value->Belt.Array.keepMap(value => value->Js.Global.decodeURIComponent->TodoStatus.parse)),

  }
}

@live
let makeQueryParams = (
  ~statuses: option<array<TodoStatus.t>>=?, 
  ()
) => {
  statuses: statuses,
}

@live
let applyQueryParams = (
  queryParams: RelayRouter__Bindings.QueryParams.t,
  ~newParams: queryParams,
) => {
  open RelayRouter__Bindings

  
  queryParams->QueryParams.setParamArrayOpt(~key="statuses", ~value=newParams.statuses->Belt.Option.map(statuses => statuses->Belt.Array.map(statuses => statuses->TodoStatus.serialize->Js.Global.encodeURIComponent)))
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
    unit
  ) => unit
}

@live
let useQueryParams = (): useQueryParamsReturn => {
  let internalSetQueryParams = RelayRouter__Internal.useSetQueryParams()
  let {search} = RelayRouter.Utils.useLocation()
  let currentQueryParams = React.useMemo1(() => {
    search->parseQueryParams
  }, [search])

  let setParams = (
    ~setter,
    ~onAfterParamsSet=?,
    ~navigationMode_=RelayRouter.Types.Push,
    ~removeNotControlledParams=true,
    ~shallow=true,
    (),
  ) => {
    let newParams = setter(currentQueryParams)

    switch onAfterParamsSet {
    | None => ()
    | Some(onAfterParamsSet) => onAfterParamsSet(newParams)
    }

    internalSetQueryParams({
      applyQueryParams: applyQueryParams(~newParams),
      currentSearch: search,
      navigationMode_: navigationMode_,
      removeNotControlledParams: removeNotControlledParams,
      shallow: shallow,
    })
  }

  {
    queryParams: currentQueryParams,
    setParams: React.useMemo2(
      () => setParams,
      (search, currentQueryParams),
    ),
  }
}

@inline
let routePattern = "/todos/:byStatus(completed|notCompleted)"

@live
let makeLink = (~byStatus: [#completed | #notCompleted], ~statuses: option<array<TodoStatus.t>>=?, ()) => {
  open RelayRouter.Bindings
  let queryParams = QueryParams.make()
  switch statuses {
    | None => ()
    | Some(statuses) => queryParams->QueryParams.setParamArray(~key="statuses", ~value=statuses->Belt.Array.map(value => value->TodoStatus.serialize->Js.Global.encodeURIComponent))
  }
  RelayRouter.Bindings.generatePath(routePattern, Js.Dict.fromArray([("byStatus", (byStatus :> string)->Js.Global.encodeURIComponent)])) ++ queryParams->QueryParams.toString
}
@live
let makeLinkFromQueryParams = (~byStatus: [#completed | #notCompleted], queryParams: queryParams) => {
  makeLink(~byStatus, ~statuses=?queryParams.statuses, ())
}


@live
type pathParam_byStatus = [#completed | #notCompleted]

@live
let isRouteActive = (~exact: bool=false, {pathname}: RelayRouter.History.location): bool => {
  RelayRouter.Internal.matchPathWithOptions({"path": routePattern, "end": exact}, pathname)->Belt.Option.isSome
}

@live
let useIsRouteActive = (~exact=false, ()) => {
  let location = RelayRouter.Utils.useLocation()
  React.useMemo2(() => location->isRouteActive(~exact), (location, exact))
}

@obj
external makeRenderer: (
  ~prepare: Internal.prepareProps => 'prepared,
  ~prepareCode: Internal.prepareProps => array<RelayRouter.Types.preloadAsset>=?,
  ~render: Internal.renderProps<'prepared> => React.element,
  unit
) => Internal.renderers<'prepared> = ""