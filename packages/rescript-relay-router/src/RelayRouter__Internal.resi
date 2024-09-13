type setQueryParamsFn<'queryParams> = (
  ~setter: 'queryParams => 'queryParams,
  ~onAfterParamsSet: 'queryParams => unit=?,
  ~navigationMode_: RelayRouter__Types.setQueryParamsMode=?,
  ~removeNotControlledParams: bool=?,
  ~shallow: bool=?,
) => unit

let useSetQueryParams: (
  ~parseQueryParams: string => 'queryParams,
  ~applyQueryParams: (RelayRouter__Bindings.QueryParams.t, ~newParams: 'queryParams) => unit,
) => setQueryParamsFn<'queryParams>

type pathMatch = {params: Js.Dict.t<string>}

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
