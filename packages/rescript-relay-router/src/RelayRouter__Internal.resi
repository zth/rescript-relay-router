type setQueryParamsFn<'queryParams> = (
  ~setter: 'queryParams => 'queryParams,
  ~onAfterParamsSet: 'queryParams => unit=?,
  ~navigationMode_: RelayRouter__Types.setQueryParamsMode=?,
  ~removeNotControlledParams: bool=?,
  ~shallow: bool=?,
) => unit

type parseQueryParamsFn<'queryParams> = RelayRouter__Bindings.QueryParams.t => 'queryParams
type applyQueryParamsFn<'queryParams> = (
  RelayRouter__Bindings.QueryParams.t,
  ~newParams: 'queryParams,
) => unit

let useSetQueryParams: (
  ~parseQueryParams: parseQueryParamsFn<'queryParams>,
  ~applyQueryParams: applyQueryParamsFn<'queryParams>,
) => setQueryParamsFn<'queryParams>

type makeNewQueryParamsMakerFn<'queryParams> = 'queryParams => 'queryParams

type makeNewQueryParamsFn<'queryParams> = makeNewQueryParamsMakerFn<'queryParams> => string

let useMakeLinkWithPreservedPath: (
  ~parseQueryParams: parseQueryParamsFn<'queryParams>,
  ~applyQueryParams: applyQueryParamsFn<'queryParams>,
) => makeNewQueryParamsFn<'queryParams>

type pathMatch = {params: dict<string>}

@module("./vendor/react-router.js") @return(nullable)
external matchPath: (string, string) => option<pathMatch> = "matchPath"

@module("./vendor/react-router.js") @return(nullable)
external matchPathWithOptions: ({"path": string, "end": bool}, string) => option<pathMatch> =
  "matchPath"

let extractDisposables: 'any => array<unit => unit>

let runAtPriority: (
  RelayRouter__Types.callback,
  ~priority: RelayRouter__Types.preloadPriority,
) => option<unit => unit>

module RouterTransitionContext: {
  type transitionFn = (unit => unit) => unit
  let context: React.Context.t<transitionFn>
  let use: unit => transitionFn

  module Provider: {
    let make: React.component<React.Context.props<transitionFn>>
  }
}

type rec routeKind<_> =
  | QueryParams({
      routePattern: string,
      parseQueryParams: RelayRouter__Bindings.QueryParams.t => 'queryParams,
    }): routeKind<'queryParams>
  | PathAndQueryParams({
      routePattern: string,
      parseQueryParams: RelayRouter__Bindings.QueryParams.t => 'queryParams,
    }): routeKind<('pathParams, 'queryParams)>
  | PathParams({routePattern: string}): routeKind<'pathParams>

let parseRoute: routeKind<'params> => (string, ~exact: bool=?) => option<'params>
