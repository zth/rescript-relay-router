// @generated
// This file is autogenerated from `todoRoutes.json`, do not edit manually.
@live
let makeLink = (~todoId: string, ~showMore: option<bool>=?, ()) => {
  open RelayRouter.Bindings
  let queryParams = QueryParams.make()
  switch showMore {
    | None => ()
    | Some(showMore) => queryParams->QueryParams.setParam(~key="showMore", ~value=string_of_bool(showMore))
  }
  `/todos/${todoId->Js.Global.encodeURIComponent}${queryParams->QueryParams.toString}`
}

@inline
let routePattern = "/todos/:todoId"

@live
let isRouteActive = (~exact: bool=false, {pathname}: RelayRouter.Bindings.History.location): bool => {
  RelayRouter.Internal.matchPathWithOptions({"path": routePattern, "end": exact}, pathname)->Belt.Option.isSome
}

@live
let useIsRouteActive = (~exact=false, ()) => {
  let location = RelayRouter.Utils.useLocation()
  React.useMemo2(() => location->isRouteActive(~exact), (location, exact))
}

@live
type prepareProps = {
  environment: RescriptRelay.Environment.t,
  location: RelayRouter.Bindings.History.location,
  todoId: string,
  showMore: option<bool>,
}

let makeRouteKey = (
  ~pathParams: Js.Dict.t<string>,
  ~queryParams: RelayRouter.Bindings.QueryParams.t
): string => {

  "Root__Todos__Single:"
    ++ pathParams->Js.Dict.get("todoId")->Belt.Option.getWithDefault("")
    ++ queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("showMore")->Belt.Option.getWithDefault("")
}

@live
let makePrepareProps = (. 
  ~environment: RescriptRelay.Environment.t,
  ~pathParams: Js.Dict.t<string>,
  ~queryParams: RelayRouter.Bindings.QueryParams.t,
  ~location: RelayRouter.Bindings.History.location,
): prepareProps => {
  {
    environment: environment,

    location: location,
    todoId: pathParams->Js.Dict.unsafeGet("todoId"),
    showMore: queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("showMore")->Belt.Option.flatMap(value => switch value {
      | "true" => Some(true)
      | "false" => Some(false)
      | _ => None
      }),
  }
}

@live
type renderProps<'prepared> = {
  childRoutes: React.element,
  prepared: 'prepared,
  environment: RescriptRelay.Environment.t,
  location: RelayRouter.Bindings.History.location,
  todoId: string,
  showMore: option<bool>,
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

type queryParams = {
  showMore: option<bool>,
}

@live
let parseQueryParams = (search: string): queryParams => {
  open RelayRouter.Bindings
  let queryParams = QueryParams.parse(search)
  {
    showMore: queryParams->QueryParams.getParamByKey("showMore")->Belt.Option.flatMap(value => switch value {
      | "true" => Some(true)
      | "false" => Some(false)
      | _ => None
      }),

  }
}

@live
let makeQueryParams = (
  ~showMore: option<bool>=?, 
  ()
) => {
  showMore: showMore,
}

@live
let setQueryParams = (
  newParams: queryParams,
  ~currentSearch: string, 
  ~navigationMode_=RelayRouter.Types.Push,
  ~removeNotControlledParams=true,
  ~history: RelayRouter.Bindings.History.t,
  ()
) => {
  open RelayRouter.Bindings

  let queryParams = if removeNotControlledParams {
    QueryParams.make()
  } else {
    QueryParams.parse(currentSearch)
  }

  
  queryParams->QueryParams.setParamOpt(~key="showMore", ~value=newParams.showMore->Belt.Option.map(showMore => string_of_bool(showMore)))
  
  queryParams->RelayRouter.Internal.setQueryParams(navigationMode_, history)
}

@live
type useQueryParamsReturn = {
  queryParams: queryParams,
  setParams: (
    ~setter: queryParams => queryParams,
    ~onAfterParamsSet: queryParams => unit=?,
    ~navigationMode_: RelayRouter.Types.setQueryParamsMode=?,
    ~removeNotControlledParams: bool=?,
    unit
  ) => unit
}

@live
let useQueryParams = (): useQueryParamsReturn => {
  let {history} = RelayRouter.useRouterContext()
  let {search} = RelayRouter.Utils.useLocation()
  let currentQueryParams = React.useMemo1(() => {
    search->parseQueryParams
  }, [search])

  let searchRef = React.useRef(search)
  let currentQueryParamsRef = React.useRef(currentQueryParams)

  searchRef.current = search
  currentQueryParamsRef.current = currentQueryParams

  {
    queryParams: currentQueryParams, 
    setParams: 
      React.useMemo0(
        () => (
          ~setter,
          ~onAfterParamsSet=?,
          ~navigationMode_=RelayRouter.Types.Push,
          ~removeNotControlledParams=true,
          ()
        ) => {
          let newParams = setter(currentQueryParamsRef.current)

          switch onAfterParamsSet {
            | None => ()
            | Some(onAfterParamsSet) => onAfterParamsSet(newParams)
          }

          newParams
            ->setQueryParams(
              ~currentSearch=searchRef.current, 
              ~navigationMode_, 
              ~removeNotControlledParams, 
              ~history, 
              ()
            )
          },
      )
  }
}