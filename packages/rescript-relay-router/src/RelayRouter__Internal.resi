let setQueryParams: (
  RelayRouter__Bindings.QueryParams.t,
  RelayRouter__Types.setQueryParamsMode,
  RelayRouter__History.t,
) => unit

type setQueryParamsFnConfig = {
  applyQueryParams: RelayRouter__Bindings.QueryParams.t => unit,
  currentSearch: string,
  navigationMode_: RelayRouter__Types.setQueryParamsMode,
  removeNotControlledParams: bool,
  shallow: bool,
}

type setQueryParamsFn = setQueryParamsFnConfig => unit

let useSetQueryParams: unit => setQueryParamsFn

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
