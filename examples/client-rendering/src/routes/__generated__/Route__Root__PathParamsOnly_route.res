// @generated
// This file is autogenerated from `todoRoutes.json`, do not edit manually.
@live
type pathParams = {
  pageSlug: string,
}

module Internal = {
  @live
  type prepareProps = {
    environment: RescriptRelay.Environment.t,
    location: RelayRouter.History.location,
    ...pathParams,
  }

  @live
  type renderProps<'prepared> = {
    childRoutes: React.element,
    prepared: 'prepared,
    environment: RescriptRelay.Environment.t,
    location: RelayRouter.History.location,
    ...pathParams,
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
    ignore(queryParams)
    {
      environment: environment,
      location: location,
      pageSlug: pathParams->Dict.getUnsafe("pageSlug"),
    }
  }

}



@inline
let routePattern = "/other/:pageSlug"

@live
let makeLink = (~pageSlug: string) => {
  RelayRouter.Bindings.generatePath(routePattern, Dict.fromArray([("pageSlug", (pageSlug :> string)->encodeURIComponent)]))
}

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
let parseRoute: (
  string,
  ~exact: bool=?,
) => option<pathParams> = RelayRouter.Internal.parseRoute(
  PathParams({routePattern: routePattern}),
)

